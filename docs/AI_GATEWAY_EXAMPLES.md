# AI Gateway Examples

## Expected Response Shape

All AI providers should be normalized to one action-safe response shape:

```json
{
  "intent": "generate_daily_plan",
  "summary": "Created a balanced plan for fat loss.",
  "actions": [
    {
      "type": "create_daily_tasks",
      "payload": {
        "date": "2026-04-13"
      }
    }
  ],
  "warnings": [
    "This is not medical advice."
  ]
}
```

## Groq Example

```http
POST https://api.groq.com/openai/v1/chat/completions
Authorization: Bearer YOUR_GROQ_API_KEY
Content-Type: application/json
```

```json
{
  "model": "llama-3.3-70b-versatile",
  "temperature": 0.2,
  "response_format": {
    "type": "json_object"
  },
  "messages": [
    {
      "role": "system",
      "content": "You are the FitNova smart fitness assistant. Return JSON only with intent, summary, actions, warnings."
    },
    {
      "role": "user",
      "content": "Make my fitness plan for tomorrow."
    }
  ]
}
```

## OpenRouter Example

```http
POST https://openrouter.ai/api/v1/chat/completions
Authorization: Bearer YOUR_OPENROUTER_API_KEY
Content-Type: application/json
HTTP-Referer: https://yourappdomain.com
X-Title: FitNova
```

```json
{
  "model": "openai/gpt-4.1-mini",
  "temperature": 0.2,
  "response_format": {
    "type": "json_object"
  },
  "messages": [
    {
      "role": "system",
      "content": "You are the FitNova smart fitness assistant. Return JSON only with intent, summary, actions, warnings."
    },
    {
      "role": "user",
      "content": "Set an alarm for 6 AM every weekday."
    }
  ]
}
```

## Validation Checklist

Before the app executes any AI action, validate:

1. `intent` exists and is in the allowed intent registry.
2. `actions` is an array.
3. Every action contains a known `type`.
4. Every action payload passes server-side schema validation.
5. Any health-related answer includes a disclaimer and avoids diagnosis.
