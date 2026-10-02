import { GoogleGenAI } from "@google/genai";
import {
  getGeminiApiKey,
  requireAiUser,
  sendSafeApiError,
  validateInlineFile,
  validateText,
} from "./_security";

export const config = {
  api: {
    bodyParser: {
      sizeLimit: '4mb',
    },
  },
};

export default async function handler(req: any, res: any) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ message: 'Only POST requests allowed' });
  }

  const user = await requireAiUser(req, res, { maxRequests: 20 });
  if (!user) return;

  try {
    const userPrompt = validateText(req.body?.userPrompt, 'User prompt', 4000);
    const courseContext = typeof req.body?.courseContext === 'string'
      ? req.body.courseContext.slice(0, 15000)
      : '';

    const ai = new GoogleGenAI({ apiKey: getGeminiApiKey() });
    const systemInstruction = `You are an AI Course Companion for the All Christian Campus Fellowship Ikole Ekiti chapter at Federal University of Oye Ekiti. Your role is to act as a helpful tutor. Based on the user's question and the provided course materials, answer their query concisely. You can summarize topics, explain concepts, or help locate information within the provided materials. If the materials don't contain the answer, politely state that the information is not available in the provided context. Format your answers clearly using Markdown, but do not use H1 or H2 markdown tags.`;

    let contents: any;
    if (req.body?.fileData || req.body?.mimeType) {
      const { fileData, mimeType } = validateInlineFile(
        req.body?.fileData,
        req.body?.mimeType,
        {
          maxBytes: 3 * 1024 * 1024,
          allowedMimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'text/plain'],
        },
      );
      contents = {
        parts: [
          { text: userPrompt },
          { inlineData: { data: fileData, mimeType } }
        ]
      };
    } else {
      contents = `${userPrompt}\n\nUse the following context if relevant:\n${courseContext || 'No specific course materials were found for this question.'}`;
    }

    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents,
      config: { systemInstruction }
    });

    return res.status(200).json({ answer: response.text ?? '' });
  } catch (error) {
    return sendSafeApiError(res, error, 'Unable to generate an AI response.');
  }
}
