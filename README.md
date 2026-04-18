# FitNova

Production-oriented Flutter mobile app scaffold for Android, powered by Supabase for backend services and Groq/OpenRouter for AI orchestration.

## Current Scope

This repository now contains:

- FitNova branding, monetization, and legal content
- a clean Flutter app shell with dark/light/system theme support
- a feature-first folder structure for scalable development
- a Supabase relational schema for core product domains
- an optional Node.js backend starter for protected AI calls
- documentation for architecture, delivery phases, and client-side inputs

## Repository Layout

```text
docs/                Product and technical planning documents
mobile/              Flutter application
backend/             Optional Node.js + Express service
supabase/            SQL schema and database setup assets
```

## Prerequisites

Before we can run the mobile app locally, this machine still needs:

- Flutter SDK 3.24+
- Android Studio toolchain

## First Documents To Read

- `docs/CLIENT_INPUTS.md`
- `docs/ARCHITECTURE.md`
- `docs/FOLDER_STRUCTURE.md`
- `docs/AI_GATEWAY_EXAMPLES.md`
- `supabase/schema.sql`

## Suggested Build Order

1. Connect Flutter SDK and initialize platform tooling.
2. Create Supabase project and run `supabase/schema.sql`.
3. Wire authentication and profile onboarding.
4. Add AI gateway secrets to the backend service.
5. Build feature modules phase by phase.

## Current Product Decisions

- App name: FitNova
- Accent color: `#8B5CF6`
- Android package: `com.fitnova.app`
- Premium pricing: `INR 199/month` or `INR 999/year`
- Wearables for v1: Google Fit
