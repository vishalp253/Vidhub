import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time_utils.dart';
import '../models/routine.dart';
import '../providers/app_providers.dart';
import 'theme.dart';
import 'widgets.dart';

/// Saved day plans. One tap swaps your schedule to a routine.
class RoutinesPage extends ConsumerWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(36, 30, 36, 32),
      children: [
        PageHeader(
          title: 'Routines',
          subtitle: 'Apply a whole day in one click. It replaces tasks from the previous routine '
              'and keeps the ones you added yourself.',
          trailing: OutlinedButton.icon(
            onPressed: () => _saveCurrent(context, ref),
            icon: const Icon(Icons.bookmark_add_outlined, size: 19),
            label: const Text('Save current schedule'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TP.text,
              side: const BorderSide(color: TP.line),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (data.routines.isEmpty)
          const TpCard(
            padding: EdgeInsets.all(28),
            child: Text(
              'No routines yet. Build a schedule you like, then use "Save current schedule".',
              style: TextStyle(fontSize: 14, color: TP.muted, height: 1.5),
            ),
          )
        else
          for (final r in data.routines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoutineCard(routine: r, applied: data.tasks.any((t) => t.routineId == r.id)),
            ),
      ],
    );
  }

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TP.surface,
        title: const Text('Save as routine', style: TextStyle(color: TP.text, fontSize: 18)),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: TP.text),
            decoration: tpInput(hint: 'Routine name, e.g. Exam week'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: TP.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: TP.accent, foregroundColor: TP.onAccent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final saved = ref.read(appControllerProvider.notifier).saveRoutine(name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Nothing to save yet: add some repeating tasks first.'
              : 'Saved "$name" with ${saved.tasks.length} tasks.',
        ),
      ),
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.routine, required this.applied});

  final Routine routine;
  final bool applied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = [...routine.tasks]..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    final days = <int>{for (final t in tasks) ...t.weekdays};
    final preview = tasks.take(5).toList();

    return TpCard(
      borderColor: applied ? TP.good.withAlpha(140) : TP.line,
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      routine.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: TP.text),
                    ),
                    if (applied) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: TP.good.withAlpha(34),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: TP.good),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tasks.isEmpty
                      ? 'No tasks'
                      : '${tasks.length} tasks  ·  ${describeWeekdays(days)}  ·  '
                          '${tasks.first.timeLabel} to ${tasks.last.timeLabel}',
                  style: const TextStyle(fontSize: 13, color: TP.muted),
                ),
                const SizedBox(height: 12),
                for (final t in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(t.timeLabel, style: const TextStyle(fontSize: 13, color: TP.muted)),
                        ),
                        Flexible(
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, color: TP.text),
                          ),
                        ),
                        if (t.items.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.rocket_launch_rounded, size: 13, color: TP.accent),
                        ],
                      ],
                    ),
                  ),
                if (tasks.length > preview.length)
                  Text(
                    '+ ${tasks.length - preview.length} more',
                    style: const TextStyle(fontSize: 12.5, color: TP.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              FilledButton(
                onPressed: tasks.isEmpty
                    ? null
                    : () {
                        final n = ref.read(appControllerProvider.notifier).applyRoutine(routine);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Applied "${routine.name}": $n tasks scheduled.')),
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: TP.accent,
                  foregroundColor: TP.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                child: Text(applied ? 'Re-apply' : 'Apply'),
              ),
              if (!routine.builtIn)
                TextButton(
                  onPressed: () => ref.read(appControllerProvider.notifier).deleteRoutine(routine.id),
                  child: const Text('Delete', style: TextStyle(color: TP.muted)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
