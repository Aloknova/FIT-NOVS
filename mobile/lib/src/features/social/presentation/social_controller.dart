import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';

final socialFriendsProvider = FutureProvider<List<SocialFriend>>((ref) async {
  final repository = ref.watch(socialRepositoryProvider);
  if (repository == null) {
    return const [];
  }

  return repository.fetchFriendOverview();
});

final socialChallengesProvider =
    FutureProvider<List<SocialChallenge>>((ref) async {
  final repository = ref.watch(socialRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repository == null || user == null) {
    return const [];
  }

  return repository.fetchChallenges(user.id);
});

final selectedChallengeIdProvider = StateProvider<String?>((ref) => null);

final challengeMessagesProvider =
    FutureProvider<List<ChallengeMessage>>((ref) async {
  final repository = ref.watch(socialRepositoryProvider);
  final challengeId = ref.watch(selectedChallengeIdProvider);
  if (repository == null || challengeId == null) {
    return const [];
  }

  return repository.fetchChallengeMessages(challengeId);
});

final socialControllerProvider =
    StateNotifierProvider<SocialController, AsyncValue<void>>((ref) {
  return SocialController(ref);
});

class SocialController extends StateNotifier<AsyncValue<void>> {
  SocialController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> requestFriend(String email) async {
    await _run(() async {
      final repository = _ref.read(socialRepositoryProvider);
      if (repository == null) {
        return;
      }

      await repository.requestFriend(email.trim());
      _ref.invalidate(socialFriendsProvider);
    });
  }

  Future<void> respondToFriend({
    required String friendshipId,
    required String status,
  }) async {
    await _run(() async {
      final repository = _ref.read(socialRepositoryProvider);
      if (repository == null) {
        return;
      }

      await repository.respondToFriend(
        friendshipId: friendshipId,
        status: status,
      );
      _ref.invalidate(socialFriendsProvider);
    });
  }

  Future<void> createChallenge({
    required String title,
    required String challengeType,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String visibility = 'public',
    double? targetValue,
    String? targetUnit,
  }) async {
    await _run(() async {
      final repository = _ref.read(socialRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      await repository.createChallenge(
        userId: user.id,
        title: title,
        challengeType: challengeType,
        startDate: startDate,
        endDate: endDate,
        description: description,
        visibility: visibility,
        targetValue: targetValue,
        targetUnit: targetUnit,
      );
      _ref.invalidate(socialChallengesProvider);
    });
  }

  Future<void> joinChallenge(String challengeId) async {
    await _run(() async {
      final repository = _ref.read(socialRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      await repository.joinChallenge(
        challengeId: challengeId,
        userId: user.id,
      );
      _ref.read(selectedChallengeIdProvider.notifier).state = challengeId;
      _ref.invalidate(socialChallengesProvider);
      _ref.invalidate(challengeMessagesProvider);
    });
  }

  Future<void> sendChallengeMessage(String content) async {
    await _run(() async {
      final repository = _ref.read(socialRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      final challengeId = _ref.read(selectedChallengeIdProvider);
      if (repository == null || user == null || challengeId == null) {
        return;
      }

      await repository.sendChallengeMessage(
        challengeId: challengeId,
        userId: user.id,
        content: content,
      );
      _ref.invalidate(challengeMessagesProvider);
    });
  }

  Future<void> deleteChallenge(String challengeId) async {
    await _run(() async {
      final repository = _ref.read(socialRepositoryProvider);
      if (repository == null) return;
      await repository.deleteChallenge(challengeId);
      _ref.invalidate(socialChallengesProvider);
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _run(() async {
      final repository = _ref.read(socialRepositoryProvider);
      if (repository == null) return;
      await repository.deleteMessage(messageId);
      _ref.invalidate(challengeMessagesProvider);
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

