import { GoogleGenAI, Type } from "@google/genai";
import {
  getGeminiApiKey,
  requireAiUser,
  sendSafeApiError,
} from "./_security";

export default async function handler(req: any, res: any) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ message: 'Only POST requests allowed' });
  }

  const user = await requireAiUser(req, res, { maxRequests: 8, windowMs: 60 * 60 * 1000 });
  if (!user) return;

  try {
    const ai = new GoogleGenAI({ apiKey: getGeminiApiKey() });
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: "Provide a single, inspiring and encouraging bible verse for a Christian fellowship dashboard. Your response must be only the JSON object, with no extra text or markdown.",
      config: {
        httpOptions: { timeout: 30_000 },
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            verse_reference: { type: Type.STRING, description: "The book, chapter, and verse (e.g., John 3:16)" },
            verse_text: { type: Type.STRING, description: "The full text of the verse." },
          },
          required: ['verse_reference', 'verse_text']
        }
      }
    });

    const jsonStr = response.text?.trim();
    if (!jsonStr) throw new Error("AI service returned an empty response.");

    return res.status(200).json(JSON.parse(jsonStr));
  } catch (error) {
    return sendSafeApiError(res, error, 'Failed to generate scripture.');
  }
}
