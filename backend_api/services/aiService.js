const { GoogleGenerativeAI } = require('@google/generative-ai');

/**
 * ✅ AI SERVICE: SUGGEST TAGS USING GEMINI
 * Analyze academic text and suggest relevant tags
 */
async function suggestTags({ title, abstract, content }, apiKey, provider = 'gemini') {
  try {
    // ✅ Validate input
    if (!title && !abstract && !content) {
      throw new Error('At least one of title, abstract, or content is required');
    }

    // ✅ Combine text for analysis
    const textToAnalyze = [
      title ? `Title: ${title}` : '',
      abstract ? `Abstract: ${abstract}` : '',
      content ? `Content: ${content.substring(0, 500)}` : '' // Limit content to 500 chars
    ].filter(Boolean).join('\n\n');

    // ✅ AI PROMPT
    const prompt = `Analyze the following academic text and suggest 3-5 highly relevant short tags (e.g., NLP, Machine Learning, Computer Vision).

${textToAnalyze}

Instructions:
- Return ONLY a comma-separated list of tags
- Each tag should be 1-3 words maximum
- Focus on research topics, methods, or domains
- Do not explain, just return the tags

Example output: "Natural Language Processing, Deep Learning, Sentiment Analysis"`;

    let tags = [];

    if (provider === 'gemini') {
      // ✅ GEMINI API
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

      const result = await model.generateContent(prompt);
      const response = result.response;
      const text = response.text();

      // Parse comma-separated tags
      tags = text
        .split(',')
        .map(tag => tag.trim())
        .filter(tag => tag.length > 0 && tag.length <= 50)
        .slice(0, 5); // Max 5 tags

    } else if (provider === 'openai') {
      // ✅ OPENAI API (fallback)
      const OpenAI = require('openai');
      const openai = new OpenAI({ apiKey });

      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: 'You are an academic research assistant.' },
          { role: 'user', content: prompt }
        ],
        max_tokens: 100,
        temperature: 0.3
      });

      const text = completion.choices[0]?.message?.content || '';
      tags = text
        .split(',')
        .map(tag => tag.trim())
        .filter(tag => tag.length > 0 && tag.length <= 50)
        .slice(0, 5);
    } else {
      throw new Error(`Unsupported AI provider: ${provider}`);
    }

    console.log(`✅ AI Tags generated: ${tags.join(', ')}`);
    return tags;

  } catch (error) {
    console.error('❌ AI Suggest Tags Error:', error.message);
    throw new Error(`Failed to generate tags: ${error.message}`);
  }
}

/**
 * ✅ AI SERVICE: PARAPHRASE TEXT
 * Rewrite academic text to avoid plagiarism while keeping meaning
 */
async function paraphraseText({ text, style }, apiKey, provider = 'gemini') {
  try {
    if (!text || text.trim().length === 0) {
      throw new Error('Text is required for paraphrasing');
    }

    // Validate style
    const validStyles = ['academic', 'simple', 'summarize'];
    const selectedStyle = validStyles.includes(style) ? style : 'academic';

    // Build prompt based on style
    let styleInstruction = '';
    switch (selectedStyle) {
      case 'academic':
        styleInstruction = 'Rewrite in formal academic tone, maintaining technical vocabulary and scholarly language.';
        break;
      case 'simple':
        styleInstruction = 'Simplify the text using clear, everyday language while keeping the core meaning intact.';
        break;
      case 'summarize':
        styleInstruction = 'Condense the text into a brief summary, highlighting only the key points.';
        break;
    }

    const prompt = `${styleInstruction}

Original Text:
"${text}"

Instructions:
- Preserve the original academic meaning and key arguments
- Change sentence structure and word choices to avoid plagiarism
- Do NOT add new information or citations
- Return ONLY the rewritten text without explanations

Rewritten Text:`;

    let result = '';

    if (provider === 'gemini') {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

      const response = await model.generateContent(prompt);
      result = response.response.text().trim();

    } else if (provider === 'openai') {
      const OpenAI = require('openai');
      const openai = new OpenAI({ apiKey });

      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: 'You are an expert academic writing assistant specialized in paraphrasing.' },
          { role: 'user', content: prompt }
        ],
        max_tokens: Math.min(text.length * 2, 1000),
        temperature: 0.7
      });

      result = completion.choices[0]?.message?.content?.trim() || '';
    } else {
      throw new Error(`Unsupported AI provider: ${provider}`);
    }

    console.log(`✅ Text paraphrased (${selectedStyle} style)`);
    return result;

  } catch (error) {
    console.error('❌ AI Paraphrase Error:', error.message);
    throw new Error(`Failed to paraphrase: ${error.message}`);
  }
}

/**
 * ✅ AI SERVICE: CRITIQUE DOCUMENT
 * Act as academic reviewer to find logical weaknesses
 */
async function critiqueDocument({ text }, apiKey, provider = 'gemini') {
  try {
    if (!text || text.trim().length === 0) {
      throw new Error('Text is required for critique');
    }

    const prompt = `Act as an expert academic peer reviewer. Analyze the following text/abstract and identify potential flaws:

Text to Review:
"${text}"

Provide a critical analysis covering:
1. **Logical Weaknesses**: Gaps in reasoning or unsupported claims
2. **Methodology Concerns**: Issues with research design or approach
3. **Missing Arguments**: What key points or counterarguments are overlooked
4. **Clarity Issues**: Ambiguous statements that need refinement

Format your response as a bulleted list with specific, constructive feedback. Be thorough but fair.

Critical Analysis:`;

    let result = '';

    if (provider === 'gemini') {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

      const response = await model.generateContent(prompt);
      result = response.response.text().trim();

    } else if (provider === 'openai') {
      const OpenAI = require('openai');
      const openai = new OpenAI({ apiKey });

      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: 'You are an expert academic reviewer known for thorough, constructive critique.' },
          { role: 'user', content: prompt }
        ],
        max_tokens: 800,
        temperature: 0.6
      });

      result = completion.choices[0]?.message?.content?.trim() || '';
    } else {
      throw new Error(`Unsupported AI provider: ${provider}`);
    }

    console.log(`✅ Document critique generated`);
    return result;

  } catch (error) {
    console.error('❌ AI Critique Error:', error.message);
    throw new Error(`Failed to critique: ${error.message}`);
  }
}

/**
 * ✅ SUGGEST MISSING LINKS: AI-powered knowledge graph connections
 * Analyze papers and suggest logical connections between them
 */
async function suggestMissingLinks(papers, apiKey, provider = 'gemini') {
  try {
    if (!Array.isArray(papers) || papers.length < 2) {
      return [];
    }

    // Build prompt with paper summaries
    const papersText = papers.map((p, idx) => 
      `Paper ${idx + 1} (ID: ${p.id}):\n` +
      `Title: ${p.title}\n` +
      `Abstract: ${(p.abstract || 'N/A').substring(0, 300)}\n` +
      `Keywords: ${p.keywords || 'N/A'}`
    ).join('\n\n---\n\n');

    const prompt = `You are an academic research assistant. Analyze these academic papers and suggest 2-3 missing logical connections between them.

${papersText}

Instructions:
1. Look for papers with similar methodologies, overlapping topics, or conflicting results
2. Suggest connections that would be valuable for a researcher
3. Each suggestion must connect two DIFFERENT papers using their IDs
4. Provide clear reasoning for each connection

Return ONLY a JSON array with this exact format:
[
  {
    "source_id": "paper_id_1",
    "target_id": "paper_id_2",
    "relation_type": "similar_methodology",
    "reasoning": "Brief explanation (max 100 words)"
  }
]

Valid relation_type values: "similar_methodology", "conflicting_results", "complementary_findings"
Return empty array [] if no meaningful connections found.`;

    let suggestions = [];

    if (provider === 'gemini') {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

      const result = await model.generateContent(prompt);
      const text = result.response.text();
      
      // Parse JSON (handle markdown code blocks)
      const cleaned = text
        .replace(/```json\s*/g, '')
        .replace(/```\s*/g, '')
        .trim();
      
      suggestions = JSON.parse(cleaned);
    } else if (provider === 'openai') {
      const OpenAI = require('openai');
      const openai = new OpenAI({ apiKey });

      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: 'You are an academic research assistant. Always respond with valid JSON.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 1024
      });

      const text = completion.choices[0]?.message?.content || '[]';
      const cleaned = text
        .replace(/```json\s*/g, '')
        .replace(/```\s*/g, '')
        .trim();
      
      suggestions = JSON.parse(cleaned);
    }

    // Validate results
    if (!Array.isArray(suggestions)) return [];

    const validIds = new Set(papers.map(p => p.id.toString()));
    const validRelations = new Set(['similar_methodology', 'conflicting_results', 'complementary_findings']);

    return suggestions.filter(s => {
      return (
        s.source_id && 
        s.target_id && 
        s.source_id !== s.target_id &&
        validIds.has(s.source_id.toString()) &&
        validIds.has(s.target_id.toString()) &&
        validRelations.has(s.relation_type) &&
        s.reasoning &&
        s.reasoning.length > 10
      );
    }).slice(0, 5); // Max 5 suggestions

  } catch (error) {
    console.error('❌ AI Missing Links Error:', error.message);
    return []; // Return empty array on error
  }
}

module.exports = { suggestTags, paraphraseText, critiqueDocument, suggestMissingLinks };


