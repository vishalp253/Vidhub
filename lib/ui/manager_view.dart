import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/time_utils.dart';
import '../logic/today_status.dart';
import '../models/app_data.dart';
import '../models/task.dart';
import '../providers/app_providers.dart';
import 'routines_page.dart';
import 'sticky_overlay_widget.dart';
import 'task_editor_dialog.dart';
import 'theme.dart';
import 'widgets.dart';

enum ManagerPage { today, tasks, routines }

/// The full app window: custom title bar, side navigation and three pages.
class ManagerView extends ConsumerStatefulWidget {
  const ManagerView({super.key});

  @override
  ConsumerState<ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends ConsumerState<ManagerView> {
  ManagerPage _page = ManagerPage.today;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TitleBar(),
        Expanded(
          child: Row(
            children: [
              _NavRail(page: _page, onSelect: (p) => setState(() => _page = p)),
              const VerticalDivider(width: 1, thickness: 1, color: TP.line),
              Expanded(
                child: switch (_page) {
                  ManagerPage.today => const TodayPage(),
                  ManagerPage.tasks => const TasksPage(),
                  ManagerPage.routines => const RoutinesPage(),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Title bar and navigation
// ---------------------------------------------------------------------------

class _TitleBar extends ConsumerWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotkeyOk = ref.watch(hotkeyStatusProvider);
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: TP.bg,
        border: Border(bottom: BorderSide(color: TP.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: TP.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'VidHub',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TP.text, letterSpacing: 0.3),
                      ),
                      if (hotkeyOk == false) ...[
                        const SizedBox(width: 16),
                        const Tooltip(
                          message: 'Another program is using Ctrl+Shift+T. Close it and restart VidHub, '
                              'or use the tray icon menu to add tasks.',
                          child: _WarnPill(text: 'Ctrl+Shift+T unavailable'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          _CaptionButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimize',
            onPressed: () => ref.read(windowServiceProvider).minimize(),
          ),
          _CaptionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close to tray',
            onPressed: () => ref.read(windowModeProvider.notifier).closeTransient(),
          ),
        ],
      ),
    );
  }
}

class _WarnPill extends StatelessWidget {
  const _WarnPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: TP.warn.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: TP.warn, fontWeight: FontWeight.w600)),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 46,
          child: Icon(icon, size: 18, color: TP.muted),
        ),
      ),
    );
  }
}

class _NavRail extends ConsumerWidget {
  const _NavRail({required this.page, required this.onSelect});

  final ManagerPage page;
  final ValueChanged<ManagerPage> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget item(ManagerPage p, IconData icon, String label) {
      final selected = p == page;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: selected ? TP.accent.withAlpha(36) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: selected ? TP.accent : TP.muted),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? TP.text : TP.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 212,
      color: TP.bg,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(ManagerPage.today, Icons.today_rounded, 'Today'),
          item(ManagerPage.tasks, Icons.checklist_rounded, 'All tasks'),
          item(ManagerPage.routines, Icons.auto_awesome_motion_rounded, 'Routines'),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Ctrl+Shift+T\nquick add from anywhere',
              style: TextStyle(fontSize: 12, color: TP.muted, height: 1.45),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => ref.read(quitProvider)(),
            icon: const Icon(Icons.power_settings_new_rounded, size: 17),
            label: const Text('Quit VidHub'),
            style: TextButton.styleFrom(foregroundColor: TP.muted, alignment: Alignment.centerLeft),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today
// ---------------------------------------------------------------------------

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).maybeWhen(data: (d) => d, orElse: DateTime.now);
    final data = ref.watch(appControllerProvider);
    final queue = ref.watch(alertQueueProvider);
    final active = queue.toSet();

    final tasks = tasksForDay(data, now);
    final doneCount = tasks.where((t) => data.statusOf(t.id, now) == DayStatus.done).length;
    final waiting = <Task>[
      for (final id in queue)
        if (data.taskById(id) != null) data.taskById(id)!,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(36, 30, 36, 32),
      children: [
        PageHeader(
          title: 'Today',
          subtitle: longDate(now),
          trailing: FilledButton.icon(
            onPressed: () async {
              final created = await showTaskEditor(context);
              if (created != null) ref.read(appControllerProvider.notifier).addTask(created);
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('New task'),
            style: FilledButton.styleFrom(
              backgroundColor: TP.accent,
              foregroundColor: TP.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (waiting.isNotEmpty) ...[
          Text('NEEDS YOU NOW', style: TP.label(color: TP.accent)),
          const SizedBox(height: 10),
          for (final t in waiting)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: TP.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TP.accent, width: 1.4),
              ),
              child: AlertCard(task: t, compact: true),
            ),
          const SizedBox(height: 10),
        ],
        if (tasks.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: doneCount / tasks.length,
                    minHeight: 6,
                    color: TP.good,
                    backgroundColor: TP.raised,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text('$doneCount of ${tasks.length} done', style: const TextStyle(fontSize: 13, color: TP.muted)),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (tasks.isEmpty)
          const _EmptyState(
            title: 'Nothing scheduled today',
            body: 'Apply a routine from the Routines page, press Ctrl+Shift+T from anywhere, '
                'or use New task.',
          )
        else
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TodayRow(task: t, state: todayState(t, data, active, now)),
            ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return TpCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: TP.text)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 14, color: TP.muted, height: 1.5)),
        ],
      ),
    );
  }
}

class _TodayRow extends ConsumerWidget {
  const _TodayRow({required this.task, required this.state});

  final Task task;
  final TodayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finished = state == TodayState.done || state == TodayState.skipped;
    final canMarkDone = state != TodayState.done;

    return TpCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              task.timeLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: finished ? TP.muted : TP.text,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: finished ? TP.muted : TP.text,
                    decoration: state == TodayState.done ? TextDecoration.lineThrough : null,
                    decorationColor: TP.muted,
                  ),
                ),
                if (task.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ItemChips(items: task.items, max: 4),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusPill(state: state),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Mark done',
            onPressed: canMarkDone
                ? () {
                    ref.read(appControllerProvider.notifier).resolve(task.id, DayStatus.done);
                    ref.read(alertQueueProvider.notifier).remove(task.id);
                    ref.read(windowModeProvider.notifier).afterAlertChange();
                  }
                : null,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
            color: TP.good,
            disabledColor: TP.line,
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () async {
              final edited = await showTaskEditor(context, initial: task);
              if (edited != null) ref.read(appControllerProvider.notifier).updateTask(edited);
            },
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: TP.muted,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All tasks
// ---------------------------------------------------------------------------

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);
    final now = ref.watch(clockProvider).maybeWhen(data: (d) => d, orElse: DateTime.now);
    final tasks = [...data.tasks]..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));

    return ListView(
      padding: const EdgeInsets.fromLTRB(36, 30, 36, 32),
      children: [
        PageHeader(
          title: 'All tasks',
          subtitle: tasks.isEmpty
              ? 'Nothing here yet'
              : '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}, ordered by time of day',
        ),
        const SizedBox(height: 22),
        if (tasks.isEmpty)
          const _EmptyState(
            title: 'No tasks yet',
            body: 'Add one from the Today page, or apply a routine to fill your day in one click.',
          )
        else
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TpCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        t.timeLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.enabled ? TP.text : TP.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: t.enabled ? TP.text : TP.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.isOneOff
                                ? 'Once  ·  ${friendlyDate(parseDateKey(t.oneOffDate!), now)}'
                                : describeWeekdays(t.weekdays),
                            style: const TextStyle(fontSize: 12.5, color: TP.muted),
                          ),
                          if (t.items.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ItemChips(items: t.items, max: 4),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: t.enabled,
                      onChanged: (v) => ref.read(appControllerProvider.notifier).setEnabled(t.id, v),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: TP.muted,
                      onPressed: () async {
                        final edited = await showTaskEditor(context, initial: t);
                        if (edited != null) ref.read(appControllerProvider.notifier).updateTask(edited);
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded, size: 21),
                      color: TP.muted,
                      onPressed: () => _confirmDelete(context, ref, t),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TP.surface,
        title: Text('Delete "${t.title}"?', style: const TextStyle(color: TP.text, fontSize: 18)),
        content: const Text(
          'It will stop alerting. This cannot be undone.',
          style: TextStyle(color: TP.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: TP.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: TP.bad, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(appControllerProvider.notifier).deleteTask(t.id);
  }
}
