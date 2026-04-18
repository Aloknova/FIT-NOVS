import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_branding.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_item.dart';

final myFeedbackProvider = FutureProvider<List<FeedbackItem>>((ref) async {
  final repository = ref.watch(feedbackRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repository == null || user == null) {
    return const [];
  }

  return repository.fetchMine(user.id);
});

final adminFeedbackProvider = FutureProvider<List<FeedbackItem>>((ref) async {
  final repository = ref.watch(feedbackRepositoryProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (repository == null ||
      profile == null ||
      !profileHasAdminAccess(profile)) {
    return const [];
  }

  return repository.fetchAdminQueue();
});

final feedbackControllerProvider =
    StateNotifierProvider<FeedbackController, AsyncValue<void>>((ref) {
  return FeedbackController(ref);
});

bool profileHasAdminAccess(profile) {
  final email = profile.email?.toLowerCase().trim();
  return profile.isAdmin ||
      (email != null && AppBranding.adminEmails.contains(email));
}

class FeedbackController extends StateNotifier<AsyncValue<void>> {
  FeedbackController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> submit({
    required String subject,
    required String message,
    int? rating,
  }) async {
    await _run(() async {
      final repository = _ref.read(feedbackRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      await repository.submit(
        userId: user.id,
        subject: subject,
        message: message,
        rating: rating,
      );
      _ref.invalidate(myFeedbackProvider);
    });
  }

  Future<void> updateAdminStatus({
    required String feedbackId,
    required String status,
    String? adminNotes,
  }) async {
    await _run(() async {
      final repository = _ref.read(feedbackRepositoryProvider);
      if (repository == null) {
        return;
      }

      await repository.updateAdminStatus(
        feedbackId: feedbackId,
        status: status,
        adminNotes: adminNotes,
      );
      _ref.invalidate(adminFeedbackProvider);
      _ref.invalidate(myFeedbackProvider);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
