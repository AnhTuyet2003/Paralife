const db = require('../config/db');
const { suggestTags, paraphraseText, critiqueDocument } = require('../services/aiService');

/**
 * ✅ API: POST /api/ai/suggest-tags
 * Generate AI-suggested tags for academic documents
 */
const suggestTagsForDocument = async (req, res) => {
  const { uid } = req.user;
  const { title, abstract, content } = req.body;

  try {
    // ✅ Validate input
    if (!title && !abstract && !content) {
      return res.status(400).json({
        success: false,
        error: 'At least one of title, abstract, or content is required'
      });
    }

    // ✅ GET USER'S AI API KEY
    const userResult = await db.query(`
      SELECT gemini_key, openai_key, use_own_key, active_provider 
      FROM users 
      WHERE firebase_uid = $1
    `, [uid]);

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

    // ✅ Validate API key exists
    if (!apiKey || apiKey.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'No AI API key configured. Please add your API key in settings.'
      });
    }

    // ✅ GENERATE TAGS USING AI
    const tags = await suggestTags({ title, abstract, content }, apiKey, provider);

    res.status(200).json({
      success: true,
      tags: tags,
      provider: provider
    });

  } catch (error) {
    console.error('❌ Suggest Tags API Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * ✅ API: POST /api/ai/paraphrase
 * Paraphrase academic text to avoid plagiarism
 */
const paraphraseTextAPI = async (req, res) => {
  const { uid } = req.user;
  const { text, style } = req.body;

  try {
    if (!text || text.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Text is required'
      });
    }

    // Get user's AI API key
    const userResult = await db.query(`
      SELECT gemini_key, openai_key, use_own_key, active_provider 
      FROM users 
      WHERE firebase_uid = $1
    `, [uid]);

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

    if (!apiKey || apiKey.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'No AI API key configured'
      });
    }

    // Paraphrase using AI
    const paraphrased = await paraphraseText({ text, style }, apiKey, provider);

    res.status(200).json({
      success: true,
      paraphrased_text: paraphrased,
      original_length: text.length,
      paraphrased_length: paraphrased.length,
      style: style || 'academic'
    });

  } catch (error) {
    console.error('❌ Paraphrase API Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * ✅ API: POST /api/ai/critique
 * Get AI critique of academic text
 */
const critiqueDocumentAPI = async (req, res) => {
  const { uid } = req.user;
  const { text } = req.body;

  try {
    if (!text || text.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Text is required'
      });
    }

    // Get user's AI API key
    const userResult = await db.query(`
      SELECT gemini_key, openai_key, use_own_key, active_provider 
      FROM users 
      WHERE firebase_uid = $1
    `, [uid]);

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

    if (!apiKey || apiKey.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'No AI API key configured'
      });
    }

    // Get critique from AI
    const critique = await critiqueDocument({ text }, apiKey, provider);

    res.status(200).json({
      success: true,
      critique: critique
    });

  } catch (error) {
    console.error('❌ Critique API Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

module.exports = { suggestTagsForDocument, paraphraseTextAPI, critiqueDocumentAPI };


