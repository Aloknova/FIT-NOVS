import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../profile/data/profile_repository.dart';
import '../domain/feedback_item.dart';
import 'feedback_controller.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(feedbackControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null || !context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    });

    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile != null && profileHasAdminAccess(profile);

    return DefaultTabController(
      length: isAdmin ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feedback'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'My feedback'),
              if (isAdmin) const Tab(text: 'Admin inbox'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isAdmin
                          ? 'User feedback and admin triage are both live on this account.'
                          : 'Send product feedback, bug reports, and feature requests straight into FitNova.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _showSubmitDialog,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Submit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _FeedbackList(
                    state: ref.watch(myFeedbackProvider),
                    emptyTitle: 'No feedback submitted yet',
                    emptySubtitle:
                        'Share bugs, feature ideas, or product polish requests.',
                  ),
                  if (isAdmin)
                    _AdminFeedbackList(state: ref.watch(adminFeedbackProvider)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubmitDialog() async {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    int rating = 5;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Send feedback'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: rating,
                      decoration: const InputDecoration(labelText: 'Rating'),
                      items: List.generate(
                        5,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1} star'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => rating = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final subject = subjectController.text.trim();
                    final message = messageController.text.trim();
                    if (subject.isEmpty || message.isEmpty) {
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    await ref.read(feedbackControllerProvider.notifier).submit(
                          subject: subject,
                          message: message,
                          rating: rating,
                        );
                  },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({
    required this.state,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final AsyncValue<List<FeedbackItem>> state;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load feedback: $error')),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(
              title: emptyTitle,
              subtitle: emptySubtitle,
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FeedbackCard(item: item);
            },
          );
        },
      ),
    );
  }
}

class _AdminFeedbackList extends ConsumerWidget {
  const _AdminFeedbackList({required this.state});

  final AsyncValue<List<FeedbackItem>> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load admin inbox: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState(
              title: 'No admin feedback in queue',
              subtitle: 'When users submit feedback it will appear here.',
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FeedbackCard(
                item: item,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => ref
                      .read(feedbackControllerProvider.notifier)
                      .updateAdminStatus(
                        feedbackId: item.id,
                        status: value,
                      ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'in_review', child: Text('In review')),
                    PopupMenuItem(value: 'resolved', child: Text('Resolved')),
                    PopupMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.item,
    this.trailing,
  });

  final FeedbackItem item;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.subject,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Text(item.message),
          const SizedBox(height: 10),
          Text(
            [
              item.status,
              if (item.rating != null) '${item.rating}/5',
              DateFormat('dd MMM, hh:mm a').format(item.createdAt),
              if (item.userEmail != null) item.userEmail!,
            ].join(' • '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.feedback_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
