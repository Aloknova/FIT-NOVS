import express from 'express';
import { z } from 'zod';

import { requireAdmin, requireAuthenticatedUser } from '../lib/supabase.js';

const router = express.Router();

const updateFeedbackSchema = z.object({
  status: z.enum(['open', 'in_review', 'resolved', 'closed']),
  adminNotes: z.string().optional(),
});

router.get('/feedback', async (request, response) => {
  try {
    const { supabase, profile } = await requireAuthenticatedUser(request);
    requireAdmin(profile);

    const { data, error } = await supabase
      .from('feedback')
      .select()
      .order('created_at', { ascending: false })
      .limit(100);

    if (error) {
      throw error;
    }

    const userIds = [...new Set((data ?? []).map((item) => item.user_id).filter(Boolean))];
    let userEmailById = {};

    if (userIds.length > 0) {
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('id, email')
        .in('id', userIds);

      if (profilesError) {
        throw profilesError;
      }

      userEmailById = Object.fromEntries(
        (profiles ?? []).map((item) => [item.id, item.email]),
      );
    }

    return response.json({
      items: (data ?? []).map((item) => ({
        ...item,
        user_email: item.user_id ? userEmailById[item.user_id] ?? null : null,
      })),
    });
  } catch (error) {
    return response.status(error.statusCode ?? 500).json({
      error: error.message ?? 'Could not load admin feedback.',
    });
  }
});

router.post('/feedback/:feedbackId/status', async (request, response) => {
  try {
    const parsed = updateFeedbackSchema.safeParse(request.body);
    if (!parsed.success) {
      return response.status(400).json({
        error: 'Invalid feedback update payload.',
        details: parsed.error.flatten(),
      });
    }

    const { supabase, profile } = await requireAuthenticatedUser(request);
    requireAdmin(profile);

    const { data, error } = await supabase
      .from('feedback')
      .update({
        status: parsed.data.status,
        admin_notes: parsed.data.adminNotes ?? null,
      })
      .eq('id', request.params.feedbackId)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return response.json({ item: data });
  } catch (error) {
    return response.status(error.statusCode ?? 500).json({
      error: error.message ?? 'Could not update feedback.',
    });
  }
});

export { router as adminRouter };
