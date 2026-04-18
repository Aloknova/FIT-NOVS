import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/connectivity_service.dart';

import '../domain/planner_models.dart';
import 'planner_controller.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(plannerControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null || !context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    });

    final theme = Theme.of(context);

    final isOnline = ref.watch(connectivityStatusProvider).valueOrNull ?? true;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planner'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'Tasks'),
              Tab(text: 'Events'),
              Tab(text: 'Alarms'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart action hub',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manual planning and AI-created actions land here: notes, personal tasks, calendar events, and alarms.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isOnline
                          ? 'Planner task sync is live. Personal tasks are cached locally and mirrored to Supabase.'
                          : 'Offline mode is active. Personal task changes are saved on this device first and sync automatically when the network returns.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOnline
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                      'All planning tools are enabled on this account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _NotesTab(onAdd: () => _showAddNoteDialog(context)),
                  _TasksTab(onAdd: () => _showAddTaskDialog(context)),
                  _EventsTab(onAdd: () => _showAddEventDialog(context)),
                  _AlarmsTab(onAdd: () => _showAddAlarmDialog(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddNoteDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Content'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty || content.isEmpty) {
                  return;
                }

                Navigator.of(context).pop();
                await ref
                    .read(plannerControllerProvider.notifier)
                    .createNote(title: title, content: content);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? dueDate;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New task'),
              content: Column(
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
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? 'No due date'
                              : 'Due ${DateFormat('dd MMM').format(dueDate!)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            initialDate: dueDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => dueDate = picked);
                          }
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                ],
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
                        .read(plannerControllerProvider.notifier)
                        .createTask(
                          title: title,
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          dueAt: dueDate,
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

  Future<void> _showAddEventDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String eventType = 'calendar';
    DateTime startAt = DateTime.now().add(const Duration(hours: 1));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: eventType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'calendar',
                          child: Text('Calendar'),
                        ),
                        DropdownMenuItem(
                          value: 'workout',
                          child: Text('Workout'),
                        ),
                        DropdownMenuItem(value: 'meal', child: Text('Meal')),
                        DropdownMenuItem(
                          value: 'reminder',
                          child: Text('Reminder'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => eventType = value);
                        }
                      },
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('dd MMM, hh:mm a').format(startAt),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              initialDate: startAt,
                            );
                            if (date == null || !context.mounted) {
                              return;
                            }
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(startAt),
                            );
                            if (time != null) {
                              setState(() {
                                startAt = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          },
                          child: const Text('Set time'),
                        ),
                      ],
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
                        .read(plannerControllerProvider.notifier)
                        .createEvent(
                          title: title,
                          startAt: startAt,
                          endAt: startAt.add(const Duration(hours: 1)),
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          eventType: eventType,
                        );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddAlarmDialog(BuildContext context) async {
    final labelController = TextEditingController();
    TimeOfDay time = const TimeOfDay(hour: 6, minute: 0);
    String repeatType = 'daily';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New alarm'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: repeatType,
                    decoration: const InputDecoration(labelText: 'Repeat'),
                    items: const [
                      DropdownMenuItem(value: 'once', child: Text('Once')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(
                        value: 'weekdays',
                        child: Text('Weekdays'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => repeatType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text('Time: ${time.format(context)}')),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (picked != null) {
                            setState(() => time = picked);
                          }
                        },
                        child: const Text('Pick time'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final label = labelController.text.trim();
                    if (label.isEmpty) {
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    final alarmTime =
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
                    await ref
                        .read(plannerControllerProvider.notifier)
                        .createAlarm(
                          label: label,
                          alarmTime: alarmTime,
                          repeatType: repeatType,
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

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionShell(
      onAdd: onAdd,
      addLabel: 'Add note',
      child: ref.watch(plannerNotesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load notes: $error')),
            data: (notes) => _buildNotes(context, notes),
          ),
    );
  }

  Widget _buildNotes(BuildContext context, List<NoteItem> notes) {
    if (notes.isEmpty) {
      return const _EmptyState(
        title: 'No notes yet',
        subtitle: 'Save ideas, AI summaries, and reminders here.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _Panel(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(note.content),
              const SizedBox(height: 10),
              Text(
                'Updated ${DateFormat('dd MMM, hh:mm a').format(note.updatedAt)} • ${note.source}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionShell(
      onAdd: onAdd,
      addLabel: 'Add task',
      child: ref.watch(plannerTasksProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load tasks: $error')),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const _EmptyState(
                  title: 'No personal tasks yet',
                  subtitle: 'Manual tasks and AI-created tasks appear here.',
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final subtitleParts = <String>[
                    if (task.description != null &&
                        task.description!.trim().isNotEmpty)
                      task.description!,
                    'Priority ${task.priority}',
                    if (task.dueAt != null)
                      'Due ${DateFormat('dd MMM').format(task.dueAt!)}',
                    if (task.createdByAi) 'AI task',
                    if (!task.isSynced) 'Pending sync',
                    if (task.isLocalOnly) 'Local first',
                  ];

                  return _Panel(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CheckboxListTile(
                      value: task.isCompleted,
                      onChanged: (_) => ref
                          .read(plannerControllerProvider.notifier)
                          .toggleTask(task),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(task.title),
                      subtitle: Text(subtitleParts.join(' • ')),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionShell(
      onAdd: onAdd,
      addLabel: 'Add event',
      child: ref.watch(plannerEventsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load events: $error')),
            data: (events) {
              if (events.isEmpty) {
                return const _EmptyState(
                  title: 'No events scheduled',
                  subtitle:
                      'Use this for workouts, meals, reminders, and calendar planning.',
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _Panel(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child:
                            Text(event.eventType.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.eventType} • ${DateFormat('dd MMM, hh:mm a').format(event.startAt)}',
                      ),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}

class _AlarmsTab extends ConsumerWidget {
  const _AlarmsTab({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionShell(
      onAdd: onAdd,
      addLabel: 'Add alarm',
      child: ref.watch(plannerAlarmsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load alarms: $error')),
            data: (alarms) {
              if (alarms.isEmpty) {
                return const _EmptyState(
                  title: 'No alarms set',
                  subtitle:
                      'Store wake-up calls, reminders, and routine alarms here.',
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: alarms.length,
                itemBuilder: (context, index) {
                  final alarm = alarms[index];
                  return _Panel(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: alarm.isEnabled,
                      onChanged: (_) => ref
                          .read(plannerControllerProvider.notifier)
                          .toggleAlarm(alarm),
                      title: Text(alarm.label),
                      subtitle: Text(
                        '${alarm.alarmTime.substring(0, 5)} • ${alarm.repeatType} • ${alarm.timezone}',
                      ),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.child,
    required this.onAdd,
    required this.addLabel,
  });

  final Widget child;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.margin = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
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
              Icons.event_note_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
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
