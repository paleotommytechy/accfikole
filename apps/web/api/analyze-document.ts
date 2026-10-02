import { GoogleGenAI, Type } from "@google/genai";
import {
  getGeminiApiKey,
  requireAiUser,
  sendSafeApiError,
  validateInlineFile,
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

  const user = await requireAiUser(req, res, { maxRequests: 15 });
  if (!user) return;

  try {
    const { fileData, mimeType } = validateInlineFile(
      req.body?.fileData,
      req.body?.mimeType,
      {
        maxBytes: 3 * 1024 * 1024,
        allowedMimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'],
      },
    );

    const ai = new GoogleGenAI({ apiKey: getGeminiApiKey() });
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: {
        parts: [
          { inlineData: { mimeType, data: fileData } },
          { text: "Extract the academic course code (e.g., GST 101, MTH 202), the academic session/year (e.g. 2023/2024), and a suitable title for this document. If it looks like a Past Question, title it 'Past Question [Year]'. If it looks like a note, title it 'Lecture Note [Topic]'. Return JSON." }
        ]
      },
      config: {
        httpOptions: { timeout: 30_000 },
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            courseCode: { type: Type.STRING },
            session: { type: Type.STRING },
            title: { type: Type.STRING },
            type: { type: Type.STRING, enum: ['past_question', 'lecture_note', 'other'] }
          }
        }
      }
    });

    const jsonStr = response.text?.trim();
    if (!jsonStr) throw new Error("AI service returned an empty response.");

    return res.status(200).json(JSON.parse(jsonStr));
  } catch (error) {
    return sendSafeApiError(res, error, 'Document analysis failed.');
  }
}
