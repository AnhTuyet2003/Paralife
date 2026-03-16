/**
 * EXTENSION CONTROLLER
 * 
 * Handles requests from Refmind Web Clipper Chrome/Edge extension
 * Simplified version - direct storage integration
 */

const axios = require('axios');
const FormData = require('form-data');
const { getStorageStrategyForUser } = require('../helpers/storageStrategyHelper');
const storageService = require('../services/storageService');
const db = require('../config/db');
const { processFileInBackground } = require('../helpers/pdfHelper');

const AI_ENGINE_URL = process.env.AI_ENGINE_URL || 'http://localhost:8000';

// ============================================
// GET CONFIG
// ============================================

/**
 * GET /api/extension/config
 * Returns Firebase API key for extension authentication
 * No auth required (public endpoint)
 */
const getConfig = async (req, res) => {
  try {
    const firebaseApiKey = process.env.FIREBASE_API_KEY;
    
    if (!firebaseApiKey) {
      return res.status(500).json({
        success: false,
        error: 'Firebase API key not configured on server'
      });
    }
    
    res.json({
      success: true,
      firebase_api_key: firebaseApiKey,
      version: '1.0.0'
    });
    
  } catch (error) {
    console.error('Error getting config:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

// ============================================
// SAVE FROM EXTENSION
// ============================================

/**
 * POST /api/extension/save
 * Saves article/webpage from browser extension
 * 
 * Request body:
 * {
 *   url: string (required),
 *   title: string (required),
 *   authors: string[] (optional),
 *   doi: string (optional),
 *   pdf_url: string (optional),
 *   abstract: string (optional),
 *   journal: string (optional),
 *   publisher: string (optional),
 *   year: string (optional),
 *   keywords: string[] (optional),
 *   tags: string[] (optional),
 *   notes: string (optional),
 *   page_type: string (optional, default: 'webpage')
 * }
 */
const saveFromExtension = async (req, res) => {
  try {
    const userId = req.user.uid;
    const {
      url,
      title,
      authors = [],
      doi,
      pdf_url,
      abstract,
      journal,
      publisher,
      year,
      keywords = [],
      tags = [],
      notes,
      page_type = 'webpage'
    } = req.body;
    
    // Validation
    if (!url || !title) {
      return res.status(400).json({
        success: false,
        error: 'URL and title are required'
      });
    }
    
    console.log(`\n📌 Extension Save Request for user ${userId}`);
    console.log(`URL: ${url}`);
    console.log(`Title: ${title}`);
    
    // Get storage strategy
    const { strategy, provider: storageProvider, cloudEmail } = 
      await getStorageStrategyForUser(userId);
    
    console.log(`   🎯 Storage: ${storageProvider}`);
    
    // Prepare metadata
    const metadata = {
      title,
      authors,
      doi,
      abstract,
      journal,
      publisher,
      year,
      keywords,
      tags,
      notes,
      url,
      page_type,
      source: 'extension',
      cloud_email: cloudEmail || null
    };
    
    let fileUrl = null;
    let sizeBytes = 0;
    let hasPdf = false;
    let aiEngineFileId = null; // Track file_id created by AI engine
    let pdfBufferForEmbedding = null;
    
    // Strategy 1: Try DOI processing
    if (doi) {
      console.log(`🔍 Processing DOI: ${doi}`);
      try {
        // Get user API keys
        const userResult = await db.query(`
          SELECT gemini_key, openai_key, use_own_key, active_provider 
          FROM users WHERE firebase_uid = $1
        `, [userId]);

        let apiKey = process.env.GEMINI_API_KEY;
        let provider = 'gemini';

        if (userResult.rows.length > 0) {
          const userData = userResult.rows[0];
          if (userData.use_own_key && userData.active_provider === 'openai') {
            provider = 'openai';
            apiKey = userData.openai_key;
          } else if (userData.use_own_key) {
            apiKey = userData.gemini_key;
          }
        }
        
        const aiResponse = await axios.post(`${AI_ENGINE_URL}/process-doi`, {
          doi: doi,
          user_id: userId,
          parent_id: null,
          api_key: apiKey,
          provider: provider
        }, { timeout: 120000 });
        
        if (aiResponse.data.success) {
          aiEngineFileId = aiResponse.data.file_id; // Always capture

          if (aiResponse.data.has_pdf) {
            console.log('✅ AI Engine found PDF');

            // Upload PDF
            const fileBuffer = Buffer.from(aiResponse.data.file_content, 'hex');
            pdfBufferForEmbedding = fileBuffer;
            const fakeFile = {
              originalname: `${title.substring(0, 50)}.pdf`,
              buffer: fileBuffer,
              size: aiResponse.data.size_bytes,
              mimetype: 'application/pdf'
            };

            storageService.setStrategy(strategy);
            const uploadResult = await storageService.uploadFile(fakeFile);
            fileUrl = uploadResult.file_url;
            sizeBytes = aiResponse.data.size_bytes;
            hasPdf = true;

            // Merge metadata
            Object.assign(metadata, aiResponse.data.metadata);
            metadata.tags = tags.length > 0 ? tags : metadata.tags;
            metadata.notes = notes || metadata.notes;
            metadata.url = url; // Keep original URL
          } else {
            console.log(`⚠️ AI Engine: no PDF found for DOI (abstract-only record: ${aiEngineFileId})`);
          }
        }
      } catch(aiError) {
        console.log(`⚠️ AI Engine failed: ${aiError.message}`);
      }
    }
    
    // Strategy 2: Try direct PDF download
    if (!hasPdf && pdf_url) {
      console.log(`🔍 Downloading PDF: ${pdf_url}`);
      try {
        const pdfResponse = await axios.get(pdf_url, {
          responseType: 'arraybuffer',
          timeout: 30000,
          maxContentLength: 50 * 1024 * 1024,
          headers: { 'User-Agent': 'Mozilla/5.0 (compatible; RefmindBot/1.0)' }
        });
        
        if (pdfResponse.status === 200) {
          const pdfBuffer = Buffer.from(pdfResponse.data);
          pdfBufferForEmbedding = pdfBuffer;
          const fakeFile = {
            originalname: `${title.substring(0, 50)}.pdf`,
            buffer: pdfBuffer,
            size: pdfBuffer.length,
            mimetype: 'application/pdf'
          };
          
          storageService.setStrategy(strategy);
          const uploadResult = await storageService.uploadFile(fakeFile);
          fileUrl = uploadResult.file_url;
          sizeBytes = pdfBuffer.length;
          hasPdf = true;
          
          console.log(`✅ PDF downloaded (${(sizeBytes / 1024 / 1024).toFixed(2)} MB)`);
        }
      } catch (downloadError) {
        console.log(`⚠️ PDF download failed: ${downloadError.message}`);
      }
    }
    
    // Save or update storage item
    let savedItemId;

    if (aiEngineFileId) {
      // AI engine already created a record — UPDATE it with PDF/metadata info
      console.log(`💾 Updating existing AI-engine record ${aiEngineFileId} (has_pdf=${hasPdf})...`);
      await db.query(
        `UPDATE storage_items
         SET file_url    = $1,
             size_bytes  = $2,
             provider    = $3,
             has_pdf     = $4,
             name        = CASE WHEN $4 THEN REPLACE(name, ' [Abstract Only]', '') ELSE name END,
             updated_at  = NOW()
         WHERE id = $5::uuid AND user_id = $6`,
        [fileUrl, sizeBytes, storageProvider, hasPdf, aiEngineFileId, userId]
      );
      savedItemId = aiEngineFileId;
      console.log(`✅ Updated: ${savedItemId}`);
    } else {
      // No AI-engine record — create from scratch
      console.log(`💾 Saving ${hasPdf ? 'with PDF' : 'metadata-only'}...`);
      const itemData = {
        parent_id: null,
        name: title,
        type: 'file',
        file_url: fileUrl,
        size_bytes: sizeBytes,
        provider: storageProvider,
        has_pdf: hasPdf,
        metadata: metadata
      };
      const item = await storageService.createStorageItem(userId, itemData);
      savedItemId = item.id;
      console.log(`✅ Saved: ${savedItemId}`);
    }

    // Rebuild vectors from PDF when available (replaces abstract-only embeddings)
    if (hasPdf && savedItemId && pdfBufferForEmbedding) {
      try {
        await db.query(
          `DELETE FROM document_embeddings WHERE file_id = $1::uuid AND user_id = $2`,
          [savedItemId, userId]
        );
        processFileInBackground(savedItemId, userId, pdfBufferForEmbedding);
      } catch (embeddingError) {
        console.error(`⚠️ Failed to trigger PDF re-embedding for ${savedItemId}: ${embeddingError.message}`);
      }
    }

    return res.json({
      success: true,
      document_id: savedItemId,
      has_pdf: hasPdf,
      storage_provider: storageProvider,
      method: hasPdf ? (doi ? 'doi_ai_engine' : 'pdf_download') : 'metadata_only'
    });
    
  } catch (error) {
    console.error('❌ Extension save error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to save from extension'
    });
  }
};

module.exports = {
  getConfig,
  saveFromExtension
};
