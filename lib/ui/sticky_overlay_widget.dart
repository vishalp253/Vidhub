import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/app_providers.dart';
import 'theme.dart';
import 'widgets.dart';

/// The always-on-top card shown in the corner of the screen when a task is
/// due. It stays until you press Done, Snooze or Skip. If several tasks are
/// due at once they queue up behind the first.
class StickyOverlayView extends ConsumerWidget {
  const StickyOverlayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(alertQueueProvider);
    final data = ref.watch(appControllerProvider);
    final tasks = <Task>[
      for (final id in queue)
        if (data.taskById(id) != null) data.taskById(id)!,
    ];

    if (tasks.isEmpty) {
      // The task behind this alert was deleted. Clean up once the frame is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(alertActionsProvider).sweep();
      });
      return const ColoredBox(color: TP.surface);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TP.surface,
        border: Border(
          left: BorderSide(color: TP.accent, width: 3),
          top: BorderSide(color: TP.line),
          right: BorderSide(color: TP.line),
          bottom: BorderSide(color: TP.line),
        ),
      ),
      child: AlertCard(task: tasks.first, waiting: tasks.length - 1),
    );
  }
}

/// One alert. Used full-size in the overlay window and [compact] inside the
/// manager window.
class AlertCard extends ConsumerWidget {
  const AlertCard({
    super.key,
    required this.task,
    this.waiting = 0,
    this.compact = false,
  });

  final Task task;

  /// How many more alerts are queued behind this one.
  final int waiting;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(alertActionsProvider);
    final error = ref.watch(launchErrorProvider);
    final hasItems = task.items.isNotEmpty;
    final openLabel =
        task.items.length == 1 ? 'Open ${task.items.first.displayName}' : 'Open ${task.items.length} items';

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const buttonHeight = Size.fromHeight(42);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PulseDot(),
              const SizedBox(width: 6),
              Text('DUE NOW  ·  ${task.timeLabel}', style: TP.label(color: TP.accent)),
              const Spacer(),
              if (waiting > 0) CountChip(text: '+$waiting waiting'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w700, color: TP.text),
          ),
          if (hasItems) ...[
            const SizedBox(height: 12),
            ItemChips(items: task.items),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(fontSize: 12.5, color: TP.bad)),
          ],
          if (compact) const SizedBox(height: 16) else const Spacer(),
          if (hasItems) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => actions.open(task.id),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(openLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(
                  backgroundColor: TP.accent,
                  foregroundColor: TP.onAccent,
                  minimumSize: buttonHeight,
                  shape: shape,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => actions.done(task.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: TP.good,
                    foregroundColor: TP.onGood,
                    minimumSize: buttonHeight,
                    shape: shape,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => actions.snooze(task.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TP.text,
                    side: const BorderSide(color: TP.line),
                    minimumSize: buttonHeight,
                    shape: shape,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  child: const Text('Snooze +10m'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => actions.skip(task.id),
                  style: TextButton.styleFrom(
                    foregroundColor: TP.muted,
                    minimumSize: buttonHeight,
                    shape: shape,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
