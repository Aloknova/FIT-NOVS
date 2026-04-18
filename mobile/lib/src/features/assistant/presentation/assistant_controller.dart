
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../diet/data/diet_repository.dart';
import '../../diet/presentation/diet_controller.dart';
import '../../health/data/health_repository.dart';
import '../../planner/data/planner_repository.dart';
import '../../planner/presentation/planner_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../todo/data/todo_repository.dart';
import '../../todo/presentation/todo_controller.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/domain/workout.dart';
import '../data/ai_repository.dart';
import '../domain/ai_message.dart';

final chatMessagesProvider = StateProvider<List<AiMessage>>((ref) => []);
final isAssistantTypingProvider = StateProvider<bool>((ref) => false);
final assistantProviderChoiceProvider = StateProvider<String>((ref) => 'groq');

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AsyncValue<void>>((ref) {
  return AssistantController(ref);
});

class AssistantController extends StateNotifier<AsyncValue<void>> {
  AssistantController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    final user = _ref.read(currentUserProvider);
    final profile = _ref.read(currentProfileProvider).valueOrNull;

    if (user == null) {
      state = AsyncError('Must be logged in to use AI.', StackTrace.current);
      return;
    }

    try {
      final repository = _ref.read(aiRepositoryProvider);
      final provider = _ref.read(assistantProviderChoiceProvider);
      await repository.enforceDailyQuota(
        userId: user.id,
        isPremium: profile?.isPremium ?? false,
        provider: provider,
      );

      final userMessage = AiMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.id,
        content: text,
        isUser: true,
        createdAt: DateTime.now(),
      );

      _ref.read(chatMessagesProvider.notifier).update(
            (state) => [...state, userMessage],
          );
      _ref.read(isAssistantTypingProvider.notifier).state = true;

      final healthSummary =
          await _ref.read(healthRepositoryProvider).fetchTodaySummary(user.id);
      final recentHistory = _ref
          .read(chatMessagesProvider)
          .take(10)
          .map((message) => message.content)
          .toList();
      final profileData = {
        ...?profile?.toUpsertMap(),
        ...?healthSummary?.toAiContextMap(),
      };

      final responseMap = await repository.sendMessage(
        userId: user.id,
        message: text,
        profileData: profileData,
        memory: recentHistory,
        provider: provider,
      );

      final intent = responseMap['intent']?.toString() ?? 'chat';
      final summary =
          responseMap['summary']?.toString() ?? 'I processed your request.';
      final actions = responseMap['actions'] as List<dynamic>? ?? [];


      await _handleActions(
        intent: intent,
        actions: actions,
        userId: user.id,
        profile: profile,
      );

      await repository.logResponse(
        userId: user.id,
        provider: provider,
        intent: intent,
        requestPayload: {
          'message': text,
          'memory': recentHistory,
          'profile': profileData,
        },
        responsePayload: responseMap,
        validatedActions: actions,
      );
      await repository.remember(
        userId: user.id,
        summary: summary,
        payload: responseMap,
        memoryType: 'conversation',
      );

      // Store only the clean summary as visible content.
      // Actions & warnings stay in metadata for structured UI rendering.
      final aiMessage = AiMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        userId: 'assistant',
        content: summary,
        isUser: false,
        createdAt: DateTime.now(),
        metadata: responseMap,
      );

      _ref.read(chatMessagesProvider.notifier).update(
            (state) => [...state, aiMessage],
          );

      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      _ref.read(isAssistantTypingProvider.notifier).state = false;
    }
  }

  Future<void> _handleActions({
    required String intent,
    required List<dynamic> actions,
    required String userId,
    required UserProfile? profile,
  }) async {
    if (profile == null) {
      return;
    }

    final todoRepository = _ref.read(todoRepositoryProvider);
    final dietRepository = _ref.read(dietRepositoryProvider);
    final plannerRepository = _ref.read(plannerRepositoryProvider);
    final normalizedIntent = intent.toLowerCase();
    final isPlanIntent = normalizedIntent == 'generate_daily_plan' ||
        normalizedIntent.contains('daily plan') ||
        normalizedIntent.contains('fitness and nutrition plan') ||
        normalizedIntent.contains('plan');

    if (isPlanIntent ||
        actions.any((action) => action.toString().contains('create_tasks'))) {
      await todoRepository?.ensureDailyPlan(
        userId: userId,
        taskDate: DateTime.now(),
        profile: profile,
      );
      _ref.invalidate(dailyTasksProvider);
    }

    if (isPlanIntent ||
        actions.any((action) => action.toString().contains('suggest_meals'))) {
      
      final suggestMealsAction = actions.firstWhere(
        (a) => a is Map && (a['type'] == 'suggest_meals' || a['intent'] == 'suggest_meals'), 
        orElse: () => null,
      );
      
      List<Map<String, dynamic>>? aiMeals;
      if (suggestMealsAction != null && suggestMealsAction['meals'] is List) {
        aiMeals = (suggestMealsAction['meals'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }

      await dietRepository?.generatePlan(
        userId: userId,
        date: DateTime.now(),
        profile: profile,
        aiMeals: aiMeals,
      );
      _ref.invalidate(dailyDietProvider);
    }

    final workoutRepository = _ref.read(workoutRepositoryProvider);
    if (actions.any((action) => action.toString().contains('suggest_workout'))) {
      final workoutAction = actions.firstWhere(
        (a) => a is Map && a['type'] == 'suggest_workout', 
        orElse: () => null,
      );
      
      if (workoutAction != null) {
        final exercises = (workoutAction['exercises'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
            
        final workout = Workout(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: workoutAction['title']?.toString() ?? 'AI Workout',
          description: workoutAction['description']?.toString() ?? 'Generated by Groq AI',
          difficulty: 'intermediate',
          goalFocus: profile.fitnessGoal ?? 'general fitness',
          durationMinutes: 45,
          caloriesEstimate: 300,
          scheduleTemplate: const [],
          instructions: exercises,
          equipment: const [],
          isPremium: false,
        );
        await workoutRepository?.createWorkout(workout: workout);
        // We could invalidate workouts provider here if there was one
      }
    }

    for (final action in actions) {
      if (action is! Map<String, dynamic>) {
        continue;
      }

      final type = action['type']?.toString().toLowerCase() ??
          action['intent']?.toString().toLowerCase();

      if (type == 'create_note') {
        await plannerRepository?.createNote(
          userId: userId,
          title: action['title']?.toString() ?? 'AI note',
          content: action['content']?.toString() ??
              action['description']?.toString() ??
              action['summary']?.toString() ??
              'Created by FitNova AI.',
          source: 'ai',
          tags: (action['tags'] as List<dynamic>? ?? [])
              .map((item) => item.toString())
              .toList(),
        );
        _ref.invalidate(plannerNotesProvider);
      }

      if (type == 'create_task') {
        await plannerRepository?.createTask(
          userId: userId,
          title: action['title']?.toString() ?? 'AI task',
          description: action['description']?.toString(),
          dueAt: _parseDateTime(action['due_at']),
          priority: (action['priority'] as num?)?.toInt() ?? 3,
          createdByAi: true,
        );
        _ref.invalidate(plannerTasksProvider);
      }

      if (type == 'create_event') {
        final startAt = _parseDateTime(action['start_at']) ??
            DateTime.now().add(const Duration(hours: 1));
        await plannerRepository?.createEvent(
          userId: userId,
          title: action['title']?.toString() ?? 'AI event',
          startAt: startAt,
          endAt: _parseDateTime(action['end_at']) ??
              startAt.add(const Duration(hours: 1)),
          description: action['description']?.toString(),
          location: action['location']?.toString(),
          eventType: action['event_type']?.toString() ?? 'calendar',
          source: 'ai',
        );
        _ref.invalidate(plannerEventsProvider);
      }

      if (type == 'set_alarm' || type == 'create_alarm') {
        final rawTime = action['time']?.toString() ??
            action['alarm_time']?.toString() ??
            '06:00';
        await plannerRepository?.createAlarm(
          userId: userId,
          label: action['label']?.toString() ?? 'AI alarm',
          alarmTime: _normalizeAlarmTime(rawTime),
          repeatType: action['repeat_type']?.toString() ?? 'daily',
          timezone: profile.timezone,
          linkedIntent: intent,
        );
        _ref.invalidate(plannerAlarmsProvider);
      }
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  String _normalizeAlarmTime(String time) {
    final trimmed = time.trim();
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmed)) {
      return '$trimmed:00';
    }
    return '06:00:00';
  }
}
