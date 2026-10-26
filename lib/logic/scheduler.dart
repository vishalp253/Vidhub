import '../core/time_utils.dart';
import '../models/app_data.dart';
import '../models/task.dart';

class SchedulerResult {
  const SchedulerResult({required this.due, required this.missedTaskIds});

  /// Tasks that should alert right now, earliest first.
  final List<Task> due;

  /// Tasks whose time passed too long ago to alert; log them as missed.
  final List<String> missedTaskIds;

  bool get isEmpty => due.isEmpty && missedTaskIds.isEmpty;
}

/// Decides, from a snapshot of the data and the clock, what needs attention.
/// Pure function: no timers, no I/O, easy to test.
class Scheduler {
  /// How late an alert may still fire. Covers waking from sleep or starting
  /// the app a bit after a task's time. Anything later is logged as missed.
  static const int graceMinutes = 30;

  static SchedulerResult evaluate({
    required DateTime now,
    required AppData data,
    Set<String> active = const <String>{},
  }) {
    final due = <(Task, DateTime)>[];
    final missed = <String>[];
    final nowMs = now.millisecondsSinceEpoch;

    for (final task in data.tasks) {
      if (!task.enabled || active.contains(task.id)) continue;

      // A snoozed task comes back when its snooze ends, and only then.
      final snoozeUntil = data.snoozes[task.id];
      if (snoozeUntil != null) {
        if (nowMs >= snoozeUntil) {
          due.add((task, DateTime.fromMillisecondsSinceEpoch(snoozeUntil)));
        }
        continue;
      }

      if (!task.occursOn(now)) continue;
      if (data.statusOf(task.id, now) != null) continue;

      final scheduled = atMinute(now, task.minuteOfDay);
      if (now.isBefore(scheduled)) continue;
      if (scheduled.millisecondsSinceEpoch < task.armedAtMs) continue;

      if (now.difference(scheduled).inMinutes > graceMinutes) {
        missed.add(task.id);
      } else {
        due.add((task, scheduled));
      }
    }

    due.sort((a, b) => a.$2.compareTo(b.$2));
    return SchedulerResult(due: [for (final d in due) d.$1], missedTaskIds: missed);
  }
}
