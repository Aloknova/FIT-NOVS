# Architecture Blueprint

## Product Modules

- Authentication
- Profile and onboarding
- AI assistant
- Daily tasks and habits
- Workout planning
- Diet planning
- Analytics and progress
- Gamification
- Social and challenges
- Notes, tasks, calendar, and alarms
- Wearables integration
- Notifications
- Feedback and admin workflows

## Technical Stack

### Mobile

- Flutter
- Riverpod for app-wide state
- Supabase Flutter SDK
- Shared Preferences for lightweight local settings
- Local notifications for reminders and alarms

### Backend

- Supabase Auth, Postgres, Storage, Realtime
- Optional Node.js + Express AI gateway for secret handling and validation

### AI

- Groq for low-latency conversational and structured tasks
- OpenRouter for model flexibility and fallback routing

## Clean Architecture Shape

Each feature should follow this structure:

```text
features/<feature_name>/
  data/
  domain/
  presentation/
```

### Layer Responsibilities

- `presentation`: screens, widgets, controllers, state
- `domain`: entities, use cases, repository contracts
- `data`: DTOs, repositories, remote/local data sources

## AI Request Flow

1. User sends a chat message.
2. Mobile app stores the local message instantly for responsiveness.
3. Message is sent to the backend AI gateway.
4. Gateway enriches the request with profile, goals, current day context, and memory.
5. Selected provider returns structured JSON only.
6. Validation layer checks intent, payload shape, and safety rules.
7. Approved actions are persisted to Supabase.
8. UI updates through direct fetch or Realtime subscriptions.

## Security Notes

- Keep service-role keys and AI keys out of the mobile app.
- Use the optional backend layer for privileged actions and model orchestration.
- Enable RLS on all user-owned tables.
- Store only minimal health data required for product features.
- Show a medical disclaimer before image/body analysis and coaching flows.

## Delivery Phases

1. Foundation
   - project setup
   - auth
   - profile
   - themes
   - dashboard shell

2. Planning Core
   - daily tasks
   - workouts
   - diet
   - progress logs

3. AI Core
   - structured assistant
   - memory
   - action handling

4. Engagement
   - analytics
   - gamification
   - notifications

5. Community
   - friends
   - chat
   - challenges

6. Advanced Integrations
   - wearables
   - image analysis
   - premium coaching

