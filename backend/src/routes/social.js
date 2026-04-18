import express from 'express';
import { z } from 'zod';

import { requireAuthenticatedUser } from '../lib/supabase.js';

const router = express.Router();

const friendRequestSchema = z.object({
  email: z.string().email(),
});

const friendResponseSchema = z.object({
  friendshipId: z.string().uuid(),
  status: z.enum(['accepted', 'declined', 'blocked']),
});

router.get('/overview', async (request, response) => {
  try {
    const { supabase, user } = await requireAuthenticatedUser(request);

    const { data: friendships, error } = await supabase
      .from('friends')
      .select()
      .or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`)
      .order('created_at', { ascending: false })
      .limit(100);

    if (error) {
      throw error;
    }

    const otherIds = [...new Set((friendships ?? []).map((item) =>
      item.requester_id === user.id ? item.addressee_id : item.requester_id,
    ))];
    let profilesById = {};

    if (otherIds.length > 0) {
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('id, full_name, email')
        .in('id', otherIds);

      if (profilesError) {
        throw profilesError;
      }

      profilesById = Object.fromEntries(
        (profiles ?? []).map((item) => [item.id, item]),
      );
    }

    return response.json({
      friends: (friendships ?? []).map((item) => {
        const otherId =
          item.requester_id === user.id ? item.addressee_id : item.requester_id;
        const profile = profilesById[otherId] ?? {};

        return {
          id: item.id,
          status: item.status,
          isIncoming: item.addressee_id === user.id,
          displayName: profile.full_name || profile.email || 'FitNova member',
          email: profile.email ?? null,
        };
      }),
    });
  } catch (error) {
    return response.status(error.statusCode ?? 500).json({
      error: error.message ?? 'Could not load social overview.',
    });
  }
});

router.post('/friends/request', async (request, response) => {
  try {
    const parsed = friendRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      return response.status(400).json({
        error: 'Invalid friend request payload.',
        details: parsed.error.flatten(),
      });
    }

    const { supabase, user } = await requireAuthenticatedUser(request);
    const email = parsed.data.email.trim().toLowerCase();

    const { data: targetProfile, error: lookupError } = await supabase
      .from('profiles')
      .select('id, email')
      .eq('email', email)
      .maybeSingle();

    if (lookupError) {
      throw lookupError;
    }

    if (!targetProfile) {
      return response.status(404).json({
        error: 'No FitNova user found with that email address.',
      });
    }

    if (targetProfile.id === user.id) {
      return response.status(400).json({
        error: 'You cannot add yourself.',
      });
    }

    const { data: existing, error: existingError } = await supabase
      .from('friends')
      .select('id, status')
      .or(
        `and(requester_id.eq.${user.id},addressee_id.eq.${targetProfile.id}),and(requester_id.eq.${targetProfile.id},addressee_id.eq.${user.id})`,
      )
      .maybeSingle();

    if (existingError) {
      throw existingError;
    }

    if (existing) {
      return response.status(409).json({
        error: `A friendship already exists with status "${existing.status}".`,
      });
    }

    const { data, error } = await supabase
      .from('friends')
      .insert({
        requester_id: user.id,
        addressee_id: targetProfile.id,
        status: 'pending',
      })
      .select()
      .single();

    if (error) {
      throw error;
    }

    return response.json({ item: data });
  } catch (error) {
    return response.status(error.statusCode ?? 500).json({
      error: error.message ?? 'Could not create friend request.',
    });
  }
});

router.post('/friends/respond', async (request, response) => {
  try {
    const parsed = friendResponseSchema.safeParse(request.body);
    if (!parsed.success) {
      return response.status(400).json({
        error: 'Invalid friend response payload.',
        details: parsed.error.flatten(),
      });
    }

    const { supabase, user } = await requireAuthenticatedUser(request);
    const { data: friendship, error: friendshipError } = await supabase
      .from('friends')
      .select()
      .eq('id', parsed.data.friendshipId)
      .single();

    if (friendshipError) {
      throw friendshipError;
    }

    if (![friendship.requester_id, friendship.addressee_id].includes(user.id)) {
      const forbidden = new Error('You are not allowed to update this friendship.');
      forbidden.statusCode = 403;
      throw forbidden;
    }

    const { data, error } = await supabase
      .from('friends')
      .update({
        status: parsed.data.status,
        responded_at: new Date().toISOString(),
      })
      .eq('id', parsed.data.friendshipId)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return response.json({ item: data });
  } catch (error) {
    return response.status(error.statusCode ?? 500).json({
      error: error.message ?? 'Could not update friendship.',
    });
  }
});

export { router as socialRouter };
