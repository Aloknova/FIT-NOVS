# What I Need From You

## Must Have Before Full Integration

1. Product identity
   - app name
   - logo or temporary text logo
   - preferred accent color or brand palette

2. Supabase access
   - Supabase project URL
   - anon key
   - service role key
   - confirmation that I should use one existing project or create a fresh schema

3. AI credentials
   - Groq API key
   - OpenRouter API key
   - preferred default models if you already have a cost/performance preference

4. Authentication setup
   - Google OAuth client IDs for Android, iOS, and web
   - Apple Developer details later for Sign in with Apple on iOS release builds

5. App identifiers
   - Android package name, for example `com.yourcompany.smartfitness`
   - iOS bundle identifier, for example `com.yourcompany.smartfitness`

6. Legal copy
   - privacy policy URL or draft text
   - terms of service URL or draft text
   - medical disclaimer wording if you already have approved text

## Needed For Feature Completion

1. Premium plan decisions
   - monthly price
   - yearly price
   - which features are premium-only

2. Wearable integrations
   - whether we should launch with Google Fit first, Apple HealthKit first, or both
   - Strava client credentials if activity sync is required in v1

3. Social model choices
   - private app only, public profiles, or mixed
   - whether chat should allow image sharing in v1

4. Notification preferences
   - default reminder times
   - whether quiet hours should be supported in v1

5. Admin operations
   - admin email accounts to seed
   - whether admin needs a separate dashboard later

## Recommended To Share Early

1. Any reference apps you like
   - examples: MyFitnessPal, Fitbit, Hevy, Strava, Headspace

2. Your target audience
   - beginners
   - busy professionals
   - weight loss
   - muscle gain
   - lifestyle coaching

3. Your v1 priorities
   - If you want the fastest path, I recommend we prioritize:
   - auth
   - profile
   - dashboard
   - daily tasks
   - workouts
   - diet
   - AI assistant

## Environment Setup Needed On This Machine

This workspace is empty and Flutter is not currently installed or available in `PATH`.

To run and verify the app here, I still need:

1. Flutter SDK installed and added to `PATH`
2. Android SDK configured
3. Xcode configured if iOS builds are required on a macOS machine later
4. Optional: Supabase CLI for local database workflows

