import { GoogleGenAI, Type } from "@google/genai";
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

  const user = await requireAiUser(req, res, { maxRequests: 15 });
  if (!user) return;

  try {
    const type = req.body?.type;
    if (type !== 'tips' && type !== 'quiz') {
      return res.status(400).json({ message: 'Unsupported generation type.' });
    }

    const courseInfo = validateText(req.body?.courseInfo, 'Course information', 1000);
    const customTopic = typeof req.body?.customTopic === 'string'
      ? req.body.customTopic.slice(0, 1000)
      : '';
    const manualContent = !req.body?.mimeType && typeof req.body?.content === 'string'
      ? req.body.content.slice(0, 15000)
      : '';

    let prompt = "";
    let responseSchema: any;

    if (type === 'tips') {
      prompt = `Provide exam strategy and study tips for ${courseInfo}. ${customTopic ? `Focus specifically on: ${customTopic}.` : ''} ${manualContent ? `Use this supplied study content as context:\n${manualContent}` : ''} Output as an object with a field "text" containing markdown formatted advice.`;
      responseSchema = {
        type: Type.OBJECT,
        properties: {
          text: { type: Type.STRING, description: "Markdown formatted study advice." }
        },
        required: ["text"]
      };
    } else {
      prompt = `Generate 5 multiple choice questions for ${courseInfo}. ${customTopic ? `Focus on: ${customTopic}.` : ''} ${manualContent ? `Use this supplied study content as context:\n${manualContent}` : ''} Each question must have 4 options and one correct_option_index (0-3). Output as JSON.`;
      responseSchema = {
        type: Type.OBJECT,
        properties: {
          questions: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                question_text: { type: Type.STRING },
                options: { type: Type.ARRAY, items: { type: Type.STRING }, minItems: 4, maxItems: 4 },
                correct_option_index: { type: Type.INTEGER, minimum: 0, maximum: 3 }
              },
              required: ["question_text", "options", "correct_option_index"]
            }
          }
        },
        required: ["questions"]
      };
    }

    const parts: any[] = [];
    if (req.body?.mimeType || (req.body?.content && !manualContent)) {
      const { fileData, mimeType } = validateInlineFile(
        req.body?.content,
        req.body?.mimeType,
        {
          maxBytes: 3 * 1024 * 1024,
          allowedMimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'],
        },
      );
      parts.push({ inlineData: { data: fileData, mimeType } });
    }
    parts.push({ text: prompt });

    const ai = new GoogleGenAI({ apiKey: getGeminiApiKey() });
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: { parts },
      config: {
        responseMimeType: "application/json",
        responseSchema,
      }
    });

    const jsonStr = response.text?.trim();
    if (!jsonStr) throw new Error("AI service returned an empty response.");

    return res.status(200).json(JSON.parse(jsonStr));
  } catch (error) {
    return sendSafeApiError(res, error, 'Learning content generation failed.');
  }
}
