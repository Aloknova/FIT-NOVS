import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/supabase_providers.dart';
import 'social_controller.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(socialControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null || !context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    });

    final theme = Theme.of(context);
    final selectedChallengeId = ref.watch(selectedChallengeIdProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Friends'),
              Tab(text: 'Challenges'),
              Tab(text: 'Chat'),
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
              child: Text(
                'Build accountability with friend invites, public challenges, and challenge-room chat.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _FriendsTab(onInvite: _showInviteDialog),
                  _ChallengesTab(
                    onCreate: _showCreateChallengeDialog,
                    currentUserId: ref.watch(currentUserProvider)?.id ?? '',
                  ),
                  _ChatTab(
                    selectedChallengeId: selectedChallengeId,
                    messageController: _messageController,
                    currentUserId: ref.watch(currentUserProvider)?.id ?? '',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInviteDialog() async {
    final emailController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invite a friend'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  return;
                }

                Navigator.of(context).pop();
                await ref
                    .read(socialControllerProvider.notifier)
                    .requestFriend(email);
              },
              child: const Text('Send request'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateChallengeDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetController = TextEditingController();
    String challengeType = 'steps';
    String visibility = 'public';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 6));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create challenge'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: challengeType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'steps', child: Text('Steps')),
                        DropdownMenuItem(
                          value: 'workout',
                          child: Text('Workout'),
                        ),
                        DropdownMenuItem(
                          value: 'hydration',
                          child: Text('Hydration'),
                        ),
                        DropdownMenuItem(
                            value: 'custom', child: Text('Custom')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => challengeType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: visibility,
                      decoration:
                          const InputDecoration(labelText: 'Visibility'),
                      items: const [
                        DropdownMenuItem(
                            value: 'public', child: Text('Public')),
                        DropdownMenuItem(
                          value: 'friends',
                          child: Text('Friends'),
                        ),
                        DropdownMenuItem(
                          value: 'private',
                          child: Text('Private'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => visibility = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target value (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Starts ${DateFormat('dd MMM').format(startDate)} • Ends ${DateFormat('dd MMM').format(endDate)}',
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
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    await ref
                        .read(socialControllerProvider.notifier)
                        .createChallenge(
                          title: title,
                          challengeType: challengeType,
                          startDate: startDate,
                          endDate: endDate,
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          visibility: visibility,
                          targetValue:
                              double.tryParse(targetController.text.trim()),
                          targetUnit: challengeType == 'hydration'
                              ? 'liters'
                              : challengeType == 'steps'
                                  ? 'steps'
                                  : null,
                        );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invite friend'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ref.watch(socialFriendsProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Could not load friends: $error')),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return const _EmptyState(
                        title: 'No friends yet',
                        subtitle:
                            'Invite someone by email to start accountability and shared challenges.',
                      );
                    }

                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                child: Text(friend.displayName.substring(0, 1)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        friend.status,
                                        if (friend.email != null) friend.email!,
                                        if (friend.isIncoming)
                                          'Incoming request',
                                      ].join(' • '),
                                    ),
                                  ],
                                ),
                              ),
                              if (friend.isIncoming &&
                                  friend.status == 'pending')
                                PopupMenuButton<String>(
                                  onSelected: (value) => ref
                                      .read(socialControllerProvider.notifier)
                                      .respondToFriend(
                                        friendshipId: friend.id,
                                        status: value,
                                      ),
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'accepted',
                                      child: Text('Accept'),
                                    ),
                                    PopupMenuItem(
                                      value: 'declined',
                                      child: Text('Decline'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _ChallengesTab extends ConsumerWidget {
  const _ChallengesTab({required this.onCreate, required this.currentUserId});

  final VoidCallback onCreate;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Create challenge'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ref.watch(socialChallengesProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Could not load challenges: $error')),
                  data: (challenges) {
                    if (challenges.isEmpty) {
                      return const _EmptyState(
                        title: 'No challenges yet',
                        subtitle:
                            'Create one to kick off social accountability.',
                      );
                    }

                    return ListView.builder(
                      itemCount: challenges.length,
                      itemBuilder: (context, index) {
                        final challenge = challenges[index];
                        final isCreator = challenge.creatorId == currentUserId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      challenge.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (isCreator)
                                    IconButton(
                                      tooltip: 'Delete challenge',
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete challenge?'),
                                            content: const Text(
                                                'This will permanently remove the challenge and all its participants.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.error,
                                                ),
                                                onPressed: () => Navigator.of(ctx).pop(true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await ref
                                              .read(socialControllerProvider.notifier)
                                              .deleteChallenge(challenge.id);
                                        }
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                [
                                  challenge.challengeType,
                                  challenge.visibility,
                                  challenge.status,
                                  '${challenge.rewardPoints} pts',
                                  '${DateFormat('dd MMM').format(challenge.startDate)}-${DateFormat('dd MMM').format(challenge.endDate)}',
                                ].join(' • '),
                              ),
                              if (challenge.description != null &&
                                  challenge.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(challenge.description!),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  FilledButton.tonal(
                                    onPressed: challenge.isJoined
                                        ? null
                                        : () => ref
                                            .read(socialControllerProvider
                                                .notifier)
                                            .joinChallenge(challenge.id),
                                    child: Text(
                                      challenge.isJoined ? 'Joined' : 'Join',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: () {
                                      ref
                                          .read(selectedChallengeIdProvider
                                              .notifier)
                                          .state = challenge.id;
                                      DefaultTabController.of(context)
                                          .animateTo(2);
                                    },
                                    child: const Text('Open chat'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _ChatTab extends ConsumerWidget {
  const _ChatTab({
    required this.selectedChallengeId,
    required this.messageController,
    required this.currentUserId,
  });

  final String? selectedChallengeId;
  final TextEditingController messageController;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          if (selectedChallengeId == null)
            const Expanded(
              child: _EmptyState(
                title: 'No challenge chat selected',
                subtitle:
                    'Pick or join a challenge from the Challenges tab, then open its room chat.',
              ),
            )
          else
            Expanded(
              child: ref.watch(challengeMessagesProvider).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text('Could not load chat: $error')),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const _EmptyState(
                          title: 'No messages yet',
                          subtitle:
                              'Start the room conversation with a quick check-in.',
                        );
                      }

                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isOwn = message.senderId == currentUserId;
                          return GestureDetector(
                            onLongPress: isOwn
                                ? () async {
                                    final choice = await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.delete_outline_rounded),
                                              title: const Text('Delete message'),
                                              onTap: () => Navigator.of(ctx).pop('delete'),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.close),
                                              title: const Text('Cancel'),
                                              onTap: () => Navigator.of(ctx).pop(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (choice == 'delete') {
                                      await ref
                                          .read(socialControllerProvider.notifier)
                                          .deleteMessage(message.id);
                                    }
                                  }
                                : null,
                            child: Align(
                              alignment: isOwn
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: const BoxConstraints(maxWidth: 280),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isOwn
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isOwn ? 20 : 4),
                                    bottomRight: Radius.circular(isOwn ? 4 : 20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isOwn
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.content,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: isOwn
                                            ? Theme.of(context).colorScheme.onPrimary
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('hh:mm a').format(message.createdAt),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isOwn
                                            ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (isOwn)
                                      Text(
                                        'Hold to delete',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          if (selectedChallengeId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Send a challenge update...',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () async {
                    final text = messageController.text.trim();
                    if (text.isEmpty) {
                      return;
                    }
                    messageController.clear();
                    await ref
                        .read(socialControllerProvider.notifier)
                        .sendChallengeMessage(text);
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
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
              Icons.groups_2_outlined,
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
