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

  const user = await requireAiUser(req, res, { maxRequests: 15 });
  if (!user) return;

  try {
    const userPrompt = validateText(req.body?.userPrompt, 'User prompt', 4000);
    const courseContext = validateText(req.body?.courseContext, 'Course context', 15000);

    const systemInstruction = `You are an expert academic advisor and study planner for a Christian university fellowship. Your goal is to create clear, actionable, and encouraging study schedules.

Based on the user's request and the provided materials, create a daily study plan leading up to the test date. The plan should be structured, easy to follow, and reference the specific materials provided.

Start with an encouraging sentence. If no specific materials are found for the requested course, politely inform the user and suggest they ask an admin to upload them.

Format the output using Markdown with lists and bold text for clarity. Do not use H1 or H2 markdown tags.`;

    const fullPrompt = `## System Instruction:\n${systemInstruction}\n\n## User Request:\n${userPrompt}\n\n## Available Course Materials:\n${courseContext}`;

    const ai = new GoogleGenAI({ apiKey: getGeminiApiKey() });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: fullPrompt,
    });

    return res.status(200).json({ plan: response.text ?? '' });
  } catch (error) {
    return sendSafeApiError(res, error, 'Study plan generation failed.');
  }
}
