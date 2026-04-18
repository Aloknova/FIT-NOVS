# FitNova Setup Status

## Received And Applied

- App name: FitNova
- Accent color: `#8B5CF6`
- Android package: `com.fitnova.app`
- Premium pricing: `INR 199/month` or `INR 999/year`
- Wearables for v1: Google Fit
- Support and admin email: `fitnova777@gmail.com`
- Privacy policy copy
- Terms and conditions copy
- Medical disclaimer copy

## Received But Intentionally Not Stored In Source Files

- Supabase credentials
- Groq API key
- OpenRouter API key

These should stay in local environment files or your deployment platform secrets, not in tracked source code.

## Still Needed

1. Android-only runtime verification on an emulator or physical device
2. Feature implementation beyond the current scaffold

## Recommended Security Follow-Up

Because secret keys were shared in chat, rotate the Supabase service-role key and the AI API keys before production release, then place the fresh values in local or hosted secret storage only.
