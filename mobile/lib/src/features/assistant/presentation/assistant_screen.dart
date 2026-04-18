import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/config/legal_content.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/ai_message.dart';
import 'assistant_controller.dart';

// ─── Voice service provider ────────────────────────────────────────────────
final _ttsProvider = Provider<FlutterTts>((ref) {
  final tts = FlutterTts();
  tts.setLanguage('en-US');
  tts.setSpeechRate(0.52);
  tts.setVolume(1.0);
  tts.setPitch(1.0);
  ref.onDispose(tts.stop);
  return tts;
});

final _isSpeakingProvider = StateProvider<bool>((ref) => false);
final _isListeningProvider = StateProvider<bool>((ref) => false);
final _voiceEnabledProvider = StateProvider<bool>((ref) => true);

// ─── Quick prompt chips ────────────────────────────────────────────────────
const _quickPrompts = [
  '🗓️ Generate my daily plan',
  '💪 Suggest a workout for today',
  '🥗 Create a meal plan',
  '⏰ Set a morning alarm',
  '📝 Note my goals',
];

// ─── Screen ────────────────────────────────────────────────────────────────
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          ref.read(_isListeningProvider.notifier).state = false;
        }
      },
      onError: (_) =>
          ref.read(_isListeningProvider.notifier).state = false,
    );
    if (!available) return;
    ref.read(_isListeningProvider.notifier).state = true;
    _speech.listen(
      onResult: (result) {
        _messageController.text = result.recognizedWords;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
        if (result.finalResult) {
          ref.read(_isListeningProvider.notifier).state = false;
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    ref.read(_isListeningProvider.notifier).state = false;
  }

  Future<void> _speak(String text) async {
    final tts = ref.read(_ttsProvider);
    // strip markdown-like characters for cleaner speech
    final clean = text
        .replaceAll(RegExp(r'Intent:.*$', multiLine: true), '')
        .replaceAll(RegExp(r'Actions:.*$', multiLine: true), '')
        .replaceAll(RegExp(r'Warnings:.*$', multiLine: true), '')
        .replaceAll(RegExp(r'[*_`#\[\]]'), '')
        .trim();
    ref.read(_isSpeakingProvider.notifier).state = true;
    await tts.speak(clean);
    tts.setCompletionHandler(() {
      if (mounted) ref.read(_isSpeakingProvider.notifier).state = false;
    });
  }

  Future<void> _stopSpeaking() async {
    await ref.read(_ttsProvider).stop();
    ref.read(_isSpeakingProvider.notifier).state = false;
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await _stopListening();
    await _stopSpeaking();
    await ref.read(assistantControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();

    // Auto-speak latest AI response
    if (ref.read(_voiceEnabledProvider)) {
      final msgs = ref.read(chatMessagesProvider);
      final last = msgs.lastOrNull;
      if (last != null && !last.isUser) {
        await _speak(last.content);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(assistantControllerProvider, (_, next) {
      final err = next.error;
      if (err == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err.toString())));
    });

    // Auto-speak when new AI message arrives
    ref.listen<List<AiMessage>>(chatMessagesProvider, (prev, next) {
      if (!ref.read(_voiceEnabledProvider)) return;
      if (next.isEmpty) return;
      final last = next.last;
      if (!last.isUser && (prev?.length ?? 0) < next.length) {
        Future.delayed(const Duration(milliseconds: 200),
            () => _speak(last.content));
      }
    });

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final messages = ref.watch(chatMessagesProvider);
    final isTyping = ref.watch(isAssistantTypingProvider);
    final isListening = ref.watch(_isListeningProvider);
    final isSpeaking = ref.watch(_isSpeakingProvider);
    final voiceEnabled = ref.watch(_voiceEnabledProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('FitNova AI'),
          ],
        ),
        actions: [
          // Voice on/off toggle
          IconButton(
            tooltip: voiceEnabled ? 'Mute voice' : 'Enable voice',
            icon: Icon(
              voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: voiceEnabled ? cs.primary : cs.outline,
            ),
            onPressed: () {
              ref.read(_voiceEnabledProvider.notifier).state = !voiceEnabled;
              if (!voiceEnabled) _stopSpeaking();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Quick prompts ──────────────────────────────────────
          if (messages.isEmpty) ...[
            _WelcomeBanner(profile: profile?.displayName),
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(_quickPrompts[i],
                      style: const TextStyle(fontSize: 13)),
                  onPressed: isTyping ? null : () => _send(_quickPrompts[i]),
                  backgroundColor: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Chat messages ──────────────────────────────────────
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 56, color: cs.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'Tap a quick prompt or type your message below.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (isTyping && i == messages.length) {
                        return const _TypingBubble();
                      }
                      final msg = messages[i];
                      return _MessageBubble(
                        message: msg,
                        onSpeak: () => _speak(msg.content),
                        onStopSpeak: _stopSpeaking,
                        isSpeaking: isSpeaking,
                      );
                    },
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────
          _InputBar(
            controller: _messageController,
            isTyping: isTyping,
            isListening: isListening,
            pulseAnim: _pulseAnim,
            onSend: _send,
            onMicTap: isListening ? _stopListening : _startListening,
            disclaimer: LegalContent.shortMedicalDisclaimer,
          ),
        ],
      ),
    );
  }
}

// ─── Welcome banner ────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({this.profile});
  final String? profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final th = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.tertiary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile != null ? 'Hello, $profile 👋' : 'Hello there 👋',
                  style: th.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'I can create your daily plan, workouts, meals, notes, alarms and events. Just ask or tap a prompt.',
                  style: th.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble ────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSpeak,
    required this.onStopSpeak,
    required this.isSpeaking,
  });

  final AiMessage message;
  final VoidCallback onSpeak;
  final VoidCallback onStopSpeak;
  final bool isSpeaking;

  static const _actionIcons = <String, IconData>{
    'generate_daily_plan': Icons.calendar_today_rounded,
    'create_task': Icons.check_circle_outline_rounded,
    'create_note': Icons.sticky_note_2_outlined,
    'create_event': Icons.event_rounded,
    'set_alarm': Icons.alarm_rounded,
    'create_alarm': Icons.alarm_rounded,
    'suggest_meals': Icons.restaurant_menu_rounded,
    'suggest_workout': Icons.fitness_center_rounded,
  };

  static const _actionLabels = <String, String>{
    'generate_daily_plan': 'Daily plan generated',
    'create_task': 'Task created',
    'create_note': 'Note saved',
    'create_event': 'Event added',
    'set_alarm': 'Alarm set',
    'create_alarm': 'Alarm set',
    'suggest_meals': 'Meals suggested',
    'suggest_workout': 'Workout generated',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUser = message.isUser;

    // Parse actions and warnings from metadata
    final meta = message.metadata;
    final rawActions =
        (meta?['actions'] as List<dynamic>? ?? []);
    final warnings =
        (meta?['warnings'] as List<dynamic>? ?? [])
            .map((w) => w.toString())
            .toList();
    final intent = meta?['intent']?.toString() ?? '';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // AI avatar label
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [cs.primary, cs.tertiary]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 6),
                    Text('FitNova AI',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700)),
                    if (intent.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          intent.replaceAll('_', ' '),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Summary bubble
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          cs.primary,
                          cs.primary.withValues(alpha: 0.85)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser ? cs.onPrimary : cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),

            // Action cards (only for AI messages with structured actions)
            if (!isUser && rawActions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...rawActions.map((action) {
                if (action is! Map<String, dynamic>) return const SizedBox();
                final type =
                    (action['type'] ?? action['intent'] ?? '')
                        .toString()
                        .toLowerCase();
                final title =
                    action['title']?.toString() ??
                    action['label']?.toString() ??
                    _actionLabels[type] ??
                    type.replaceAll('_', ' ');
                final icon = _actionIcons[type] ?? Icons.bolt_rounded;
                final label = _actionLabels[type] ?? 'Action executed';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.secondary.withValues(alpha: 0.25),
                        width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: cs.secondary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(
                                        color: cs.onSecondaryContainer
                                            .withValues(alpha: 0.7))),
                            Text(title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSecondaryContainer,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded,
                          size: 14,
                          color: cs.secondary),
                    ],
                  ),
                );
              }),
            ],

            // Warning chips
            if (!isUser && warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14,
                        color: cs.onErrorContainer),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        warnings.first,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onErrorContainer, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Listen / stop button
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: GestureDetector(
                  onTap: isSpeaking ? onStopSpeak : onSpeak,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSpeaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        size: 14,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSpeaking ? 'Stop' : 'Listen',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Typing bubble ─────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final offset = sin((_ctrl.value * 2 * pi) - (i * pi / 2));
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8 + (4 * ((offset + 1) / 2)),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.6 + 0.4 * ((offset + 1) / 2)),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Input bar ─────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isTyping,
    required this.isListening,
    required this.pulseAnim,
    required this.onSend,
    required this.onMicTap,
    required this.disclaimer,
  });

  final TextEditingController controller;
  final bool isTyping;
  final bool isListening;
  final Animation<double> pulseAnim;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mic button
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: isListening ? pulseAnim.value : 1.0,
                  child: child,
                ),
                child: GestureDetector(
                  onTap: onMicTap,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isListening
                          ? cs.errorContainer
                          : cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: isListening
                          ? cs.onErrorContainer
                          : cs.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Text field
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: isListening
                        ? 'Listening…'
                        : 'Ask anything — plans, workouts, meals…',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              GestureDetector(
                onTap: isTyping ? null : onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: isTyping
                        ? null
                        : LinearGradient(
                            colors: [cs.primary, cs.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isTyping ? cs.surfaceContainerHighest : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: isTyping ? cs.outline : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            disclaimer,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
