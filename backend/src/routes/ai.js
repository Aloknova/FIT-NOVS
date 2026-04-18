import express from 'express';
import { z } from 'zod';

const router = express.Router();

const chatSchema = z.object({
  provider: z.enum(['groq']).default('groq'),
  userId: z.string().optional(),
  message: z.string().min(1),
  memory: z.array(z.string()).default([]),
  profile: z
      .object({
        goal: z.string().optional(),
        fitness_goal: z.string().optional(),
        age: z.number().int().positive().optional(),
        gender: z.string().optional(),
        weight_kg: z.number().optional(),
        height_cm: z.number().optional(),
        activity_level: z.string().optional(),
      })
      .passthrough()
      .default({}),
});

const aiResponseSchema = z.object({
  intent: z.string(),
  summary: z.string(),
  actions: z.array(z.any()).default([]),
  warnings: z.array(z.string()).default([]),
});

router.post('/chat', async (request, response) => {
  const parsed = chatSchema.safeParse(request.body);

  if (!parsed.success) {
    return response.status(400).json({
      error: 'Invalid request payload',
      details: parsed.error.flatten(),
    });
  }

  const start = Date.now();
  const { provider, message, memory, profile } = parsed.data;
  const apiKey = process.env.GROQ_API_KEY;

  if (!apiKey) {
    return response.status(500).json({
      error: `Groq API key is not configured`,
    });
  }

  try {
    const payload = buildRequestPayload({ message, memory, profile });
    const { model, rawResponse } = await callProvider({
      apiKey,
      payload,
    });

    const content = rawResponse?.choices?.[0]?.message?.content;
    const parsedResponse = parseAiJson(content);
    const aiResponse = aiResponseSchema.parse(parsedResponse);
    const normalizedResponse = normalizeResponse(aiResponse);

    return response.json({
      ...normalizedResponse,
      provider,
      model,
      latency_ms: Date.now() - start,
    });
  } catch (error) {
    return response.status(500).json({
      intent: 'error',
      summary: 'The AI request could not be completed right now.',
      actions: [],
      warnings: [String(error)],
      provider,
      model: process.env.GROQ_MODEL ?? 'llama3-8b-8192',
      latency_ms: Date.now() - start,
    });
  }
});

const dietSchema = z.object({
  userId: z.string().optional(),
  profile: z.object({
    goal: z.string().optional(),
    fitness_goal: z.string().optional(),
    age: z.number().int().positive().optional(),
    gender: z.string().optional(),
    weight_kg: z.number().optional(),
    height_cm: z.number().optional(),
    activity_level: z.string().optional(),
  }).passthrough().default({}),
});

router.post('/diet-plan', async (request, response) => {
  const parsed = dietSchema.safeParse(request.body);
  if (!parsed.success) {
    return response.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
  }

  const start = Date.now();
  const { profile } = parsed.data;
  const apiKey = process.env.GROQ_API_KEY;

  if (!apiKey) return response.status(500).json({ error: 'Groq API key not configured' });

  try {
    const systemPrompt = [
      'You are a professional nutrition coach.',
      'Generate a 100% vegetarian daily meal plan.',
      'Return JSON ONLY.',
      'JSON structure: {"title": "...", "calorie_target": 2000, "protein_g": 150, "carbs_g": 200, "fat_g": 60, "meals": [{"type": "Breakfast", "food": "...", "calories": 500, "protein_g": 30}, ...]}',
      'The plan must be tailored to this profile: ' + JSON.stringify(profile),
      'All food must be vegetarian (plant-based, dairy, eggs are allowed). No meat or fish.',
    ].join(' ');

    const payload = {
      model: process.env.GROQ_MODEL ?? 'llama-3.3-70b-versatile',
      temperature: 0.3,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: 'Generate my daily vegetarian diet plan for today.' },
      ],
    };

    const { rawResponse } = await callProvider({ apiKey, payload });
    const content = rawResponse?.choices?.[0]?.message?.content;
    const plan = parseAiJson(content);

    return response.json({
      ...plan,
      latency_ms: Date.now() - start,
    });
  } catch (error) {
    return response.status(500).json({ error: 'Failed to generate diet plan', details: String(error) });
  }
});

function buildRequestPayload({ message, memory, profile }) {
  const model = process.env.GROQ_MODEL ?? 'llama3-8b-8192';

  const systemPrompt = [
    'You are the FitNova smart fitness and life assistant.',
    'Return JSON only.',
    'The JSON must contain: intent, summary, actions, warnings.',
    'Actions must be an array.',
    'IMPORTANT: All meal and diet suggestions MUST be 100% vegetarian. Never suggest meat, fish, seafood, or any non-vegetarian food. Only suggest plant-based foods, dairy, and eggs.',
    'When the user asks for a diet plan, meal plan, workout plan, or training routine, you MUST act as their expert coach and generate the specific meals and workouts tailored to their profile.',
    'Supported action object types are: generate_daily_plan, create_task, create_note, create_event, set_alarm, suggest_meals, suggest_workout.',
    'For suggest_meals, return: {"type":"suggest_meals", "meals": [{"type": "Breakfast", "food": "...", "calories": 400, "protein_g": 20}, ...]}',
    'For suggest_workout, return: {"type":"suggest_workout", "title": "...", "description": "...", "exercises": ["...", "..."]}',
    'Each action object must include a "type" field and the fields needed to execute it.',
    'Examples: {"type":"create_task","title":"10 minute mobility","description":"Morning recovery flow"}, {"type":"create_note","title":"Morning reflection","content":"Check energy, hydration, and intention for the day"}, {"type":"set_alarm","label":"Morning workout","time":"06:00","repeat_type":"daily"}, {"type":"create_event","title":"Upper body session","event_type":"workout","start_at":"2026-04-17T07:00:00Z"}.',
    'Warnings must include a medical disclaimer when health, diet, exercise, body metrics, or recovery are discussed.',
    'Never diagnose disease or claim to provide medical advice.',
    'Keep the summary concise and actionable.',
  ].join(' ');

  return {
    model,
    temperature: 0.2,
    response_format: {
      type: 'json_object',
    },
    messages: [
      {
        role: 'system',
        content: systemPrompt,
      },
      {
        role: 'system',
        content: `User profile: ${JSON.stringify(profile)}`,
      },
      {
        role: 'system',
        content: `Recent memory: ${JSON.stringify(memory.slice(-8))}`,
      },
      {
        role: 'user',
        content: message,
      },
    ],
  };
}

async function callProvider({ apiKey, payload }) {
  const rawResponse = await postJson({
    url: 'https://api.groq.com/openai/v1/chat/completions',
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: payload,
  });

  return { model: payload.model, rawResponse };
}

async function postJson({ url, headers, body }) {
  const result = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });

  const text = await result.text();
  const json = text ? JSON.parse(text) : {};

  if (!result.ok) {
    throw new Error(
      json?.error?.message || text || `Request failed with ${result.status}`,
    );
  }

  return json;
}

function parseAiJson(content) {
  if (typeof content === 'string') {
    return JSON.parse(content);
  }

  if (Array.isArray(content)) {
    const text = content
        .map((part) => {
          if (typeof part === 'string') {
            return part;
          }
          return part?.text ?? '';
        })
        .join('');

    return JSON.parse(text);
  }

  throw new Error('AI response did not contain parseable JSON content.');
}

function normalizeResponse(response) {
  const rawIntent = response.intent?.toLowerCase() ?? 'chat';
  let intent = response.intent;
  let warnings = Array.isArray(response.warnings) ? response.warnings : [];

  if (
    rawIntent.includes('daily plan') ||
    rawIntent.includes('fitness and nutrition plan') ||
    rawIntent.includes('nutrition plan')
  ) {
    intent = 'generate_daily_plan';
  }

  const isWellnessIntent =
    rawIntent.includes('plan') ||
    rawIntent.includes('diet') ||
    rawIntent.includes('fitness') ||
    rawIntent.includes('workout') ||
    rawIntent.includes('nutrition');
  if (isWellnessIntent && warnings.length === 0) {
    warnings = [
      'This guidance is for general wellness information only and is not medical advice.',
    ];
  }

  return {
    ...response,
    intent,
    warnings,
  };
}

export { router as aiRouter };
