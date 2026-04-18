import { createClient } from '@supabase/supabase-js';

let adminClient;

function getSupabaseAdminClient() {
  if (adminClient) {
    return adminClient;
  }

  const url = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
  }

  adminClient = createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  return adminClient;
}

async function requireAuthenticatedUser(request) {
  const authorization = request.headers.authorization ?? '';
  const token = authorization.startsWith('Bearer ')
    ? authorization.slice(7)
    : null;

  if (!token) {
    const error = new Error('Missing bearer token.');
    error.statusCode = 401;
    throw error;
  }

  const supabase = getSupabaseAdminClient();
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    const authError = new Error(error?.message ?? 'Invalid session.');
    authError.statusCode = 401;
    throw authError;
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select()
    .eq('id', data.user.id)
    .single();

  if (profileError || !profile) {
    const missingProfileError = new Error(
      profileError?.message ?? 'Profile not found.',
    );
    missingProfileError.statusCode = 403;
    throw missingProfileError;
  }

  return {
    supabase,
    user: data.user,
    profile,
  };
}

function requireAdmin(profile) {
  const configuredEmails = (process.env.FITNOVA_ADMIN_EMAILS ??
    'fitnova777@gmail.com')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  const email = profile.email?.toLowerCase().trim();
  const isAdmin = profile.role === 'admin' || configuredEmails.includes(email);

  if (!isAdmin) {
    const error = new Error('Admin access is required.');
    error.statusCode = 403;
    throw error;
  }
}

export { getSupabaseAdminClient, requireAuthenticatedUser, requireAdmin };
