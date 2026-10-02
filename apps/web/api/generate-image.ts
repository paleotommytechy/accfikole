import { GoogleGenAI } from "@google/genai";
import {
  getGeminiApiKey,
  requireAiUser,
  sendSafeApiError,
  validateText,
} from "./_security";

export default async function handler(req: any, res: any) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ message: 'Only POST requests allowed' });
  }

  const user = await requireAiUser(req, res, {
    allowedRoles: ['admin', 'blog'],
    maxRequests: 6,
    windowMs: 15 * 60 * 1000,
  });
  if (!user) return;

  try {
    const prompt = validateText(req.body?.prompt, 'Prompt', 500);
    const ai = new GoogleGenAI({ apiKey: getGeminiApiKey() });
    const response = await ai.models.generateImages({
      model: 'imagen-4.0-generate-001',
      prompt: `A cinematic, high-quality hero image for a blog post titled: "${prompt}". The image should be visually appealing and relevant to the title. No text in the image.`,
      config: { numberOfImages: 1, httpOptions: { timeout: 30_000 } },
    });

    const base64ImageBytes = response.generatedImages?.[0]?.image?.imageBytes;
    if (!base64ImageBytes) throw new Error('AI image service returned no image.');

    return res.status(200).json({ base64Image: base64ImageBytes });
  } catch (error) {
    return sendSafeApiError(res, error, 'Image generation failed.');
  }
}
