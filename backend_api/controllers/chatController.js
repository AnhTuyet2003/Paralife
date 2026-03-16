const db = require('../config/db');
const axios = require('axios');
const crossrefService = require('../services/crossrefService');

// ✅ AI ENGINE BASE URL
const AI_ENGINE_URL = process.env.AI_ENGINE_URL || 'http://localhost:8000';

// Create chat session
const createSession = async (req, res) => {
  const { uid } = req.user;
  const { file_id, mode } = req.body;

  try {
    // ✅ Xác định type dựa vào mode
    let sessionType = 'single_doc';
    let relatedFileId = file_id || null;
    let title = 'Trò chuyện mới';

    if (mode === 'library') {
      sessionType = 'library';
      relatedFileId = null;
      title = '📚 Chat với Toàn bộ Thư viện';
    } else if (mode === 'document' && file_id) {
      sessionType = 'single_doc';
      // Lấy tên file để làm title
      const fileQuery = 'SELECT name FROM storage_items WHERE id = $1';
      const fileResult = await db.query(fileQuery, [file_id]);
      if (fileResult.rows.length > 0) {
        title = `💬 Chat: ${fileResult.rows[0].name}`;
      }
    }

    // ✅ CAST user_id
    const query = `
      INSERT INTO chat_sessions (user_id, related_file_id, title, type)
      VALUES ($1::TEXT, $2, $3, $4)
      RETURNING *
    `;
    const result = await db.query(query, [uid, relatedFileId, title, sessionType]);

    const session = result.rows[0];
    
    res.status(201).json({
      success: true,
      id: session.id,
      title: session.title,
      type: session.type,
      created_at: session.created_at
    });
  } catch (error) {
    console.error('❌ Create Session Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Send message
const sendMessage = async (req, res) => {
  const { uid } = req.user;
  const { session_id, content } = req.body;

  if (!session_id || !content) {
    return res.status(400).json({ success: false, error: 'session_id and content required' });
  }

  try {
    // ✅ 1. VERIFY SESSION
    const verifyQuery = `
      SELECT s.*, si.name as file_name 
      FROM chat_sessions s
      LEFT JOIN storage_items si ON s.related_file_id = si.id
      WHERE s.id = $1 AND s.user_id = $2::TEXT
    `;
    const verifyResult = await db.query(verifyQuery, [session_id, uid]);

    if (verifyResult.rows.length === 0) {
      return res.status(403).json({ success: false, error: 'Session not found or unauthorized' });
    }

    const session = verifyResult.rows[0];

    // ✅ 2. LƯU USER MESSAGE VÀO DB
    const userMsgQuery = `
      INSERT INTO chat_messages (session_id, role, content, citations)
      VALUES ($1, 'user', $2, '[]'::jsonb)
      RETURNING *
    `;
    await db.query(userMsgQuery, [session_id, content]);

    // ✅ 3. LẤY API KEY CỦA USER
    const userQuery = `
      SELECT gemini_key, openai_key, use_own_key, active_provider 
      FROM users 
      WHERE firebase_uid = $1
    `;
    const userResult = await db.query(userQuery, [uid]);

    let apiKey = process.env.GEMINI_API_KEY;
    let provider = 'gemini';

    if (userResult.rows.length > 0) {
      const userData = userResult.rows[0];
      if (userData.use_own_key && userData.active_provider === 'openai') {
        provider = 'openai';
        apiKey = userData.openai_key;
      } else if (userData.use_own_key && userData.gemini_key) {
        apiKey = userData.gemini_key;
      }
    }

    // ✅ 4. GỌI AI ENGINE PYTHON
    console.log(`🤖 Calling AI Engine for message: "${content.substring(0, 50)}..."`);
    
    const aiResponse = await axios.post(`${AI_ENGINE_URL}/chat`, {
      message: content,
      user_id: uid,
      file_id: session.related_file_id, // null nếu chat library
      api_key: apiKey
    }, {
      timeout: 60000 // 60 seconds
    });

    const aiAnswer = aiResponse.data.answer || 'Xin lỗi, tôi không thể trả lời câu hỏi này.';
    const citations = aiResponse.data.citations || [];

    // ✅ 5. LƯU AI RESPONSE VÀO DB
    const aiMsgQuery = `
      INSERT INTO chat_messages (session_id, role, content, citations)
      VALUES ($1, 'ai', $2, $3::jsonb)
      RETURNING *
    `;
    const aiMsgResult = await db.query(aiMsgQuery, [
      session_id,
      aiAnswer,
      JSON.stringify(citations)
    ]);

    const aiMessage = aiMsgResult.rows[0];

    // ✅ 6. TRẢ VỀ CHO FLUTTER
    res.status(201).json({
      id: aiMessage.id,
      role: 'ai',
      content: aiMessage.content,
      citations: aiMessage.citations,
      created_at: aiMessage.created_at
    });

  } catch (error) {
    console.error('❌ Send Message Error:', error);
    
    // Return error message as AI response
    res.status(500).json({
      id: Date.now().toString(),
      role: 'ai',
      content: `❌ Lỗi: ${error.message || 'Không thể kết nối AI Engine'}`,
      citations: [],
      created_at: new Date().toISOString()
    });
  }
};

// Get messages
const getMessages = async (req, res) => {
  const { uid } = req.user;
  const { session_id } = req.params;

  try {
    // ✅ CAST user_id
    const verifyQuery = 'SELECT * FROM chat_sessions WHERE id = $1 AND user_id = $2::TEXT';
    const verifyResult = await db.query(verifyQuery, [session_id, uid]);

    if (verifyResult.rows.length === 0) {
      return res.status(403).json({ success: false, error: 'Unauthorized' });
    }

    const messagesQuery = `
      SELECT * FROM chat_messages 
      WHERE session_id = $1 
      ORDER BY created_at ASC
    `;
    const result = await db.query(messagesQuery, [session_id]);

    res.status(200).json(result.rows);
  } catch (error) {
    console.error('❌ Get Messages Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Get summary (tích hợp với AI)
const getSummary = async (req, res) => {
  const { uid } = req.user;
  const { file_id, type } = req.body;

  if (!file_id) {
    return res.status(400).json({ success: false, error: 'file_id required' });
  }

  try {
    // ✅ 1. VERIFY FILE OWNERSHIP
    const fileQuery = 'SELECT * FROM storage_items WHERE id = $1 AND user_id = $2::TEXT';
    const fileResult = await db.query(fileQuery, [file_id, uid]);

    if (fileResult.rows.length === 0) {
      return res.status(403).json({ success: false, error: 'File not found or unauthorized' });
    }

    // ✅ 2. LẤY API KEY
    const userQuery = `
      SELECT gemini_key, openai_key, use_own_key, active_provider 
      FROM users 
      WHERE firebase_uid = $1
    `;
    const userResult = await db.query(userQuery, [uid]);

    let apiKey = process.env.GEMINI_API_KEY;

    if (userResult.rows.length > 0) {
      const userData = userResult.rows[0];
      if (userData.use_own_key && userData.active_provider === 'openai') {
        apiKey = userData.openai_key;
      } else if (userData.use_own_key && userData.gemini_key) {
        apiKey = userData.gemini_key;
      }
    }

    // ✅ 3. GỌI AI ENGINE PYTHON
    const summaryType = type || 'detailed'; // detailed, tldr, bullet
    console.log(`📝 Requesting ${summaryType} summary for file: ${file_id}`);

    const aiResponse = await axios.post(`${AI_ENGINE_URL}/summarize-document`, {
      file_id: file_id,
      api_key: apiKey,
      summary_type: summaryType
    }, {
      timeout: 90000 // 90 seconds (summary mất nhiều thời gian)
    });

    const summary = aiResponse.data.summary || 'Không thể tạo tóm tắt.';

    // ✅ 4. TRẢ VỀ CHO FLUTTER
    res.status(200).json({
      success: true,
      summary: summary,
      type: summaryType,
      file_id: file_id
    });

  } catch (error) {
    console.error('❌ Get Summary Error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Failed to generate summary' 
    });
  }
};

// Explain term (placeholder - cần tích hợp AI)
const explainTerm = async (req, res) => {
  const { uid } = req.user;
  const { term, context } = req.body;

  try {
    // TODO: Tích hợp với AI service
    res.status(200).json({
      success: true,
      message: 'Explain feature coming soon',
      data: { term, explanation: 'AI explanation will be generated here' }
    });
  } catch (error) {
    console.error('❌ Explain Term Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Compare documents (placeholder - cần tích hợp AI)
const compareDocuments = async (req, res) => {
  const { uid } = req.user;
  const { file_ids } = req.body;

  try {
    if (!Array.isArray(file_ids) || file_ids.length < 2) {
      return res.status(400).json({
        success: false,
        error: 'Cần chọn ít nhất 2 tài liệu để so sánh'
      });
    }

    // Giới hạn tối đa để tránh truy vấn quá lớn.
    const limitedFileIds = file_ids.slice(0, 5);

    const query = `
      SELECT id, name, metadata
      FROM storage_items
      WHERE user_id = $1::TEXT
        AND type = 'file'
        AND id = ANY($2::uuid[])
    `;

    const result = await db.query(query, [uid, limitedFileIds]);

    if (result.rows.length < 2) {
      return res.status(404).json({
        success: false,
        error: 'Không tìm thấy đủ tài liệu hợp lệ để so sánh'
      });
    }

    const normalizeText = (value, fallback = '-') => {
      if (value === null || value === undefined) return fallback;
      if (Array.isArray(value)) {
        const joined = value
          .map((v) => (v == null ? '' : String(v).trim()))
          .filter(Boolean)
          .join(', ')
          .trim();
        return joined || fallback;
      }

      const text = String(value).trim();
      if (!text) return fallback;

      const lowered = text.toLowerCase();
      if (['n/a', 'na', 'null', 'undefined'].includes(lowered)) {
        return fallback;
      }

      return text;
    };

    const buildMetadataMatrix = (rows) => rows.map((doc) => {
      const metadata = doc.metadata || {};
      return {
        file_id: doc.id,
        file_name: doc.name,
        method: normalizeText(
          metadata.method || metadata.methodology || metadata.approach || metadata.research_method || metadata.technique
        ),
        data: normalizeText(
          metadata.data || metadata.dataset || metadata.sample || metadata.materials || metadata.population
        ),
        result: normalizeText(
          metadata.result || metadata.findings || metadata.conclusion || metadata.summary || metadata.abstract
        ),
        limitation: normalizeText(
          metadata.limitation || metadata.limitations || metadata.challenges || metadata.gaps || metadata.processing_error
        ),
        year: normalizeText(metadata.year),
        journal: normalizeText(metadata.journal),
        authors: normalizeText(metadata.authors),
        abstract: normalizeText(metadata.abstract)
      };
    });

    const fileNameById = Object.fromEntries(result.rows.map((row) => [String(row.id), row.name]));
    const docsById = Object.fromEntries(result.rows.map((row) => [String(row.id), row]));

    let matrix = [];
    let source = 'metadata_fallback';
    let missingFiles = [];
    let researchFallbackCount = 0;

    try {
      console.log(`📊 Calling AI compare for ${limitedFileIds.length} documents...`);
      const aiResponse = await axios.post(
        `${AI_ENGINE_URL}/compare-documents`,
        { file_ids: limitedFileIds, user_id: uid },
        { timeout: 180000 }
      );

      const aiMatrix = Array.isArray(aiResponse.data?.matrix) ? aiResponse.data.matrix : [];
      if (aiMatrix.length > 0) {
        matrix = aiMatrix.map((item) => ({
          file_id: item.file_id,
          file_name: normalizeText(item.file_name || fileNameById[String(item.file_id)]),
          method: normalizeText(item.method),
          data: normalizeText(item.data),
          result: normalizeText(item.result),
          limitation: normalizeText(item.limitation),
          year: '-',
          journal: '-',
          authors: '-',
          abstract: '-'
        }));
        source = 'ai_engine';

        const returnedIds = new Set(aiMatrix.map((item) => String(item.file_id)).filter(Boolean));
        const missingDocRows = result.rows.filter((row) => !returnedIds.has(String(row.id)));

        missingFiles = missingDocRows.map((row) => ({
          file_id: row.id,
          file_name: row.name,
          reason: 'missing_embeddings'
        }));

        // Fallback research from trusted source (Crossref) for missing rows.
        for (const row of missingDocRows) {
          const md = row.metadata || {};
          let researchMetadata = null;

          if (md.doi) {
            const doiCheck = await crossrefService.validateDOI(md.doi);
            if (doiCheck?.isValid && doiCheck?.metadata) {
              researchMetadata = doiCheck.metadata;
            }
          }

          if (!researchMetadata) {
            const titleCandidate = md.title || row.name;
            const titleSearch = await crossrefService.searchByTitle(titleCandidate);
            if (titleSearch?.found && titleSearch?.metadata) {
              researchMetadata = titleSearch.metadata;
            }
          }

          if (researchMetadata) {
            matrix.push({
              file_id: row.id,
              file_name: normalizeText(researchMetadata.title || row.name),
              method: 'Tra cuu tu nguon hoc thuat (Crossref), chua co trich xuat full-text.',
              data: normalizeText(researchMetadata.journal || researchMetadata.type),
              result: normalizeText(researchMetadata.abstract || 'Chua co ket qua phan tich tu full-text.'),
              limitation: 'Tai lieu chua co embeddings/document chunks trong he thong.',
              year: normalizeText(researchMetadata.year),
              journal: normalizeText(researchMetadata.journal),
              authors: normalizeText(researchMetadata.authors),
              abstract: normalizeText(researchMetadata.abstract)
            });
            researchFallbackCount += 1;
          }
        }
      }
    } catch (aiError) {
      const aiDetails = aiError.response?.data || aiError.message;
      console.warn('⚠️ AI compare unavailable, using metadata fallback:', aiDetails);
    }

    if (matrix.length === 0) {
      matrix = buildMetadataMatrix(result.rows);
      missingFiles = result.rows
        .filter((row) => {
          const md = row.metadata || {};
          const hasAnyStructuredData = md.method || md.methodology || md.approach || md.research_method ||
            md.data || md.dataset || md.sample || md.materials || md.population ||
            md.result || md.findings || md.conclusion || md.summary;
          return !hasAnyStructuredData;
        })
        .map((row) => ({
          file_id: row.id,
          file_name: row.name,
          reason: 'missing_metadata'
        }));
    }

    res.status(200).json({
      success: true,
      matrix,
      total: matrix.length,
      source,
      missing_files: missingFiles,
      research_fallback_count: researchFallbackCount
    });
  } catch (error) {
    console.error('❌ Compare Documents Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  createSession,
  sendMessage,
  getMessages,
  getSummary,
  explainTerm,
  compareDocuments
};