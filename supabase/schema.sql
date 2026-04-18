create extension if not exists pgcrypto;

comment on schema public is
  'Supabase auth.users is the canonical users table. Public tables reference auth.users(id).';

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.calculate_bmi(height_cm numeric, weight_kg numeric)
returns numeric
language sql
immutable
as $$
  select case
    when height_cm is null or height_cm <= 0 or weight_kg is null or weight_kg <= 0 then null
    else round((weight_kg / power(height_cm / 100.0, 2))::numeric, 2)
  end
$$;

create or replace function public.sync_profile_derived_fields()
returns trigger
language plpgsql
as $$
begin
  if new.email is null then
    select email into new.email
    from auth.users
    where id = new.id;
  end if;

  new.bmi = public.calculate_bmi(new.height_cm, new.weight_kg);
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  full_name text,
  avatar_url text,
  role text not null default 'user' check (role in ('user', 'admin')),
  age integer check (age between 13 and 120),
  gender text,
  height_cm numeric(5,2) check (height_cm > 0),
  weight_kg numeric(5,2) check (weight_kg > 0),
  bmi numeric(5,2),
  fitness_goal text,
  activity_level text,
  theme_preference text not null default 'system'
    check (theme_preference in ('system', 'light', 'dark')),
  is_premium boolean not null default true,
  timezone text not null default 'UTC',
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists profiles_sync_derived_fields on public.profiles;
create trigger profiles_sync_derived_fields
before insert or update on public.profiles
for each row execute function public.sync_profile_derived_fields();

create table if not exists public.user_points (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  total_points integer not null default 0 check (total_points >= 0),
  level integer not null default 1 check (level >= 1),
  current_streak integer not null default 0 check (current_streak >= 0),
  longest_streak integer not null default 0 check (longest_streak >= 0),
  last_activity_date date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do nothing;

  insert into public.user_points (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  -- Grant full access to every new user.
  update public.profiles set is_premium = true where id = new.id;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_type text not null
    check (goal_type in ('weight_loss', 'weight_gain', 'muscle_gain', 'maintenance', 'habit', 'performance')),
  title text not null,
  description text,
  target_value numeric(10,2),
  current_value numeric(10,2),
  target_unit text,
  start_date date not null default current_date,
  target_date date,
  status text not null default 'active'
    check (status in ('active', 'paused', 'completed', 'archived')),
  ai_managed boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.daily_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  task_date date not null,
  title text not null,
  description text,
  category text not null
    check (category in ('breakfast', 'lunch', 'dinner', 'workout', 'water', 'steps', 'sleep', 'custom')),
  source text not null default 'ai'
    check (source in ('ai', 'system', 'manual')),
  target_value numeric(10,2),
  target_unit text,
  points_reward integer not null default 0 check (points_reward >= 0),
  is_required boolean not null default true,
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'skipped', 'missed')),
  scheduled_time time,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, task_date, title)
);

create table if not exists public.task_logs (
  id uuid primary key default gen_random_uuid(),
  daily_task_id uuid not null references public.daily_tasks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  completed boolean not null default false,
  value numeric(10,2),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  logged_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.profiles(id) on delete set null,
  title text not null,
  description text,
  difficulty text not null
    check (difficulty in ('beginner', 'intermediate', 'advanced')),
  goal_focus text not null,
  duration_minutes integer not null check (duration_minutes > 0),
  calories_estimate integer,
  schedule_template jsonb not null default '[]'::jsonb,
  instructions jsonb not null default '[]'::jsonb,
  equipment jsonb not null default '[]'::jsonb,
  is_premium boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.diet_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  plan_date date not null,
  calorie_target integer not null check (calorie_target > 0),
  protein_g numeric(10,2),
  carbs_g numeric(10,2),
  fat_g numeric(10,2),
  meals jsonb not null default '[]'::jsonb,
  source text not null default 'ai' check (source in ('ai', 'coach', 'manual')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, plan_date)
);

create table if not exists public.health_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  metric_type text not null
    check (metric_type in ('steps', 'heart_rate', 'spo2', 'calories', 'sleep', 'weight', 'distance')),
  metric_value numeric(12,2) not null,
  metric_unit text not null,
  source text not null
    check (source in ('manual', 'google_fit', 'apple_health', 'strava', 'device', 'ai')),
  recorded_at timestamptz not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.progress_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  log_date date not null,
  weight_kg numeric(5,2),
  body_fat_percentage numeric(5,2),
  chest_cm numeric(5,2),
  waist_cm numeric(5,2),
  hips_cm numeric(5,2),
  steps integer,
  calories_burned integer,
  sleep_minutes integer,
  notes text,
  progress_photo_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, log_date)
);

create table if not exists public.ai_memory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  memory_type text not null
    check (memory_type in ('profile', 'preference', 'habit', 'goal', 'conversation', 'insight')),
  summary text not null,
  memory_payload jsonb not null default '{}'::jsonb,
  priority smallint not null default 1 check (priority between 1 and 5),
  last_used_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.ai_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider in ('groq', 'openrouter')),
  model text not null,
  intent text,
  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb not null default '{}'::jsonb,
  validated_actions jsonb not null default '[]'::jsonb,
  status text not null check (status in ('success', 'blocked', 'error')),
  latency_ms integer,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.friends (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'blocked')),
  requested_at timestamptz not null default timezone('utc', now()),
  responded_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create unique index if not exists friends_unique_pair_idx
  on public.friends (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  challenge_type text not null
    check (challenge_type in ('steps', 'workout', 'weight_loss', 'hydration', 'custom')),
  target_value numeric(10,2),
  target_unit text,
  reward_points integer not null default 0 check (reward_points >= 0),
  visibility text not null default 'friends'
    check (visibility in ('private', 'friends', 'public')),
  start_date date not null,
  end_date date not null,
  status text not null default 'draft'
    check (status in ('draft', 'active', 'completed', 'cancelled')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (end_date >= start_date)
);

create table if not exists public.challenge_participants (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default timezone('utc', now()),
  progress_value numeric(10,2) not null default 0,
  is_winner boolean not null default false,
  unique (challenge_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid references public.profiles(id) on delete cascade,
  challenge_id uuid references public.challenges(id) on delete cascade,
  message_type text not null default 'text'
    check (message_type in ('text', 'image', 'system')),
  content text not null,
  attachment_url text,
  metadata jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  check (
    (recipient_id is not null and challenge_id is null) or
    (recipient_id is null and challenge_id is not null)
  )
);

create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  icon_url text,
  tier text not null check (tier in ('bronze', 'silver', 'gold', 'platinum')),
  points_threshold integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  awarded_at timestamptz not null default timezone('utc', now()),
  award_reason text,
  unique (user_id, badge_id)
);

create table if not exists public.leaderboard (
  id uuid primary key default gen_random_uuid(),
  period_type text not null check (period_type in ('weekly', 'monthly', 'all_time')),
  period_start date not null,
  period_end date,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rank integer not null check (rank > 0),
  score integer not null check (score >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  unique (period_type, period_start, user_id),
  unique (period_type, period_start, rank)
);

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  content text not null,
  source text not null default 'manual' check (source in ('manual', 'ai')),
  ai_summary text,
  tags text[] not null default '{}'::text[],
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  due_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'in_progress', 'completed', 'cancelled')),
  priority smallint not null default 3 check (priority between 1 and 5),
  created_by_ai boolean not null default false,
  linked_intent text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  event_type text not null default 'calendar'
    check (event_type in ('calendar', 'workout', 'meal', 'reminder', 'challenge')),
  start_at timestamptz not null,
  end_at timestamptz,
  location text,
  source text not null default 'manual' check (source in ('manual', 'ai', 'system')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (end_at is null or end_at >= start_at)
);

create table if not exists public.alarms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  alarm_time time not null,
  timezone text not null default 'UTC',
  repeat_type text not null default 'daily'
    check (repeat_type in ('once', 'daily', 'weekdays', 'custom')),
  repeat_days smallint[] not null default '{}'::smallint[],
  is_enabled boolean not null default true,
  next_trigger_at timestamptz,
  linked_intent text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  subject text not null,
  message text not null,
  rating smallint check (rating between 1 and 5),
  status text not null default 'open'
    check (status in ('open', 'in_review', 'resolved', 'closed')),
  admin_notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_goals_user_status on public.goals (user_id, status);
create index if not exists idx_daily_tasks_user_date on public.daily_tasks (user_id, task_date desc);
create index if not exists idx_task_logs_user_logged_at on public.task_logs (user_id, logged_at desc);
create index if not exists idx_diet_plans_user_date on public.diet_plans (user_id, plan_date desc);
create index if not exists idx_health_metrics_user_type_time on public.health_metrics (user_id, metric_type, recorded_at desc);
create index if not exists idx_progress_logs_user_date on public.progress_logs (user_id, log_date desc);
create index if not exists idx_ai_memory_user_last_used on public.ai_memory (user_id, last_used_at desc nulls last);
create index if not exists idx_ai_logs_user_created on public.ai_logs (user_id, created_at desc);
create index if not exists idx_messages_recipient_created on public.messages (recipient_id, created_at desc);
create index if not exists idx_messages_challenge_created on public.messages (challenge_id, created_at desc);
create index if not exists idx_challenges_status_dates on public.challenges (status, start_date, end_date);
create index if not exists idx_notes_user_updated on public.notes (user_id, updated_at desc);
create index if not exists idx_tasks_user_status_due on public.tasks (user_id, status, due_at);
create index if not exists idx_events_user_start on public.events (user_id, start_at);
create index if not exists idx_alarms_user_enabled on public.alarms (user_id, is_enabled);
create index if not exists idx_feedback_status_created on public.feedback (status, created_at desc);
create index if not exists idx_leaderboard_period_rank on public.leaderboard (period_type, period_start, rank);

drop trigger if exists goals_set_updated_at on public.goals;
create trigger goals_set_updated_at before update on public.goals
for each row execute function public.set_updated_at();
drop trigger if exists daily_tasks_set_updated_at on public.daily_tasks;
create trigger daily_tasks_set_updated_at before update on public.daily_tasks
for each row execute function public.set_updated_at();
drop trigger if exists user_points_set_updated_at on public.user_points;
create trigger user_points_set_updated_at before update on public.user_points
for each row execute function public.set_updated_at();
drop trigger if exists workouts_set_updated_at on public.workouts;
create trigger workouts_set_updated_at before update on public.workouts
for each row execute function public.set_updated_at();
drop trigger if exists diet_plans_set_updated_at on public.diet_plans;
create trigger diet_plans_set_updated_at before update on public.diet_plans
for each row execute function public.set_updated_at();
drop trigger if exists progress_logs_set_updated_at on public.progress_logs;
create trigger progress_logs_set_updated_at before update on public.progress_logs
for each row execute function public.set_updated_at();
drop trigger if exists ai_memory_set_updated_at on public.ai_memory;
create trigger ai_memory_set_updated_at before update on public.ai_memory
for each row execute function public.set_updated_at();
drop trigger if exists friends_set_updated_at on public.friends;
create trigger friends_set_updated_at before update on public.friends
for each row execute function public.set_updated_at();
drop trigger if exists challenges_set_updated_at on public.challenges;
create trigger challenges_set_updated_at before update on public.challenges
for each row execute function public.set_updated_at();
drop trigger if exists notes_set_updated_at on public.notes;
create trigger notes_set_updated_at before update on public.notes
for each row execute function public.set_updated_at();
drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at before update on public.tasks
for each row execute function public.set_updated_at();
drop trigger if exists events_set_updated_at on public.events;
create trigger events_set_updated_at before update on public.events
for each row execute function public.set_updated_at();
drop trigger if exists alarms_set_updated_at on public.alarms;
create trigger alarms_set_updated_at before update on public.alarms
for each row execute function public.set_updated_at();
drop trigger if exists feedback_set_updated_at on public.feedback;
create trigger feedback_set_updated_at before update on public.feedback
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.user_points enable row level security;
alter table public.goals enable row level security;
alter table public.daily_tasks enable row level security;
alter table public.task_logs enable row level security;
alter table public.workouts enable row level security;
alter table public.diet_plans enable row level security;
alter table public.health_metrics enable row level security;
alter table public.progress_logs enable row level security;
alter table public.ai_memory enable row level security;
alter table public.ai_logs enable row level security;
alter table public.friends enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_participants enable row level security;
alter table public.messages enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;
alter table public.leaderboard enable row level security;
alter table public.notes enable row level security;
alter table public.tasks enable row level security;
alter table public.events enable row level security;
alter table public.alarms enable row level security;
alter table public.feedback enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_delete_own" on public.profiles;
drop policy if exists "user_points_own" on public.user_points;
drop policy if exists "goals_own" on public.goals;
drop policy if exists "daily_tasks_own" on public.daily_tasks;
drop policy if exists "task_logs_own" on public.task_logs;
drop policy if exists "workouts_read_authenticated" on public.workouts;
drop policy if exists "diet_plans_own" on public.diet_plans;
drop policy if exists "health_metrics_own" on public.health_metrics;
drop policy if exists "progress_logs_own" on public.progress_logs;
drop policy if exists "ai_memory_own" on public.ai_memory;
drop policy if exists "ai_logs_own" on public.ai_logs;
drop policy if exists "friends_visible_to_participants" on public.friends;
drop policy if exists "friends_create_request" on public.friends;
drop policy if exists "friends_update_participants" on public.friends;
drop policy if exists "challenges_creator_or_participant_view" on public.challenges;
drop policy if exists "challenges_creator_manage" on public.challenges;
drop policy if exists "challenge_participants_visible" on public.challenge_participants;
drop policy if exists "challenge_participants_join_self" on public.challenge_participants;
drop policy if exists "challenge_participants_update_self" on public.challenge_participants;
drop policy if exists "messages_visible_to_members" on public.messages;
drop policy if exists "messages_send_as_self" on public.messages;
drop policy if exists "badges_read_authenticated" on public.badges;
drop policy if exists "user_badges_own" on public.user_badges;
drop policy if exists "leaderboard_read_authenticated" on public.leaderboard;
drop policy if exists "notes_own" on public.notes;
drop policy if exists "tasks_own" on public.tasks;
drop policy if exists "events_own" on public.events;
drop policy if exists "alarms_own" on public.alarms;
drop policy if exists "feedback_own" on public.feedback;

create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "profiles_delete_own"
  on public.profiles for delete
  using (auth.uid() = id);

create policy "user_points_own"
  on public.user_points for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "goals_own"
  on public.goals for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "daily_tasks_own"
  on public.daily_tasks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "task_logs_own"
  on public.task_logs for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "workouts_read_authenticated"
  on public.workouts for select
  using (auth.role() = 'authenticated');

create policy "diet_plans_own"
  on public.diet_plans for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "health_metrics_own"
  on public.health_metrics for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "progress_logs_own"
  on public.progress_logs for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "ai_memory_own"
  on public.ai_memory for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "ai_logs_own"
  on public.ai_logs for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "friends_visible_to_participants"
  on public.friends for select
  using (auth.uid() in (requester_id, addressee_id));

create policy "friends_create_request"
  on public.friends for insert
  with check (auth.uid() = requester_id);

create policy "friends_update_participants"
  on public.friends for update
  using (auth.uid() in (requester_id, addressee_id))
  with check (auth.uid() in (requester_id, addressee_id));

create policy "challenges_creator_or_participant_view"
  on public.challenges for select
  using (
    auth.uid() = creator_id
    or exists (
      select 1
      from public.challenge_participants cp
      where cp.challenge_id = challenges.id
        and cp.user_id = auth.uid()
    )
    or visibility = 'public'
  );

create policy "challenges_creator_manage"
  on public.challenges for all
  using (auth.uid() = creator_id)
  with check (auth.uid() = creator_id);

create policy "challenge_participants_visible"
  on public.challenge_participants for select
  using (auth.uid() = user_id);

create policy "challenge_participants_join_self"
  on public.challenge_participants for insert
  with check (auth.uid() = user_id);

create policy "challenge_participants_update_self"
  on public.challenge_participants for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "messages_visible_to_members"
  on public.messages for select
  using (
    auth.uid() = sender_id
    or auth.uid() = recipient_id
    or exists (
      select 1
      from public.challenge_participants cp
      where cp.challenge_id = messages.challenge_id
        and cp.user_id = auth.uid()
    )
  );

create policy "messages_send_as_self"
  on public.messages for insert
  with check (
    auth.uid() = sender_id
    and (
      recipient_id is not null
      or exists (
        select 1
        from public.challenge_participants cp
        where cp.challenge_id = messages.challenge_id
          and cp.user_id = auth.uid()
      )
    )
  );

create policy "badges_read_authenticated"
  on public.badges for select
  using (auth.role() = 'authenticated');

create policy "user_badges_own"
  on public.user_badges for select
  using (auth.uid() = user_id);

create policy "leaderboard_read_authenticated"
  on public.leaderboard for select
  using (auth.role() = 'authenticated');

create policy "notes_own"
  on public.notes for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "tasks_own"
  on public.tasks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "events_own"
  on public.events for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "alarms_own"
  on public.alarms for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "feedback_own"
  on public.feedback for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('progress-media', 'progress-media', false)
on conflict (id) do nothing;
