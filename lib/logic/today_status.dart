import '../core/time_utils.dart';
import '../models/app_data.dart';
import '../models/task.dart';

enum TodayState { done, skipped, missed, due, snoozed, upcoming, earlier }

/// How a task looks in today's list.
TodayState todayState(Task task, AppData data, Set<String> active, DateTime now) {
  final logged = data.statusOf(task.id, now);
  if (logged == DayStatus.done) return TodayState.done;
  if (logged == DayStatus.skipped) return TodayState.skipped;
  if (logged == DayStatus.missed) return TodayState.missed;
  if (active.contains(task.id)) return TodayState.due;
  if (data.snoozes.containsKey(task.id)) return TodayState.snoozed;
  final scheduled = atMinute(now, task.minuteOfDay);
  return scheduled.isAfter(now) ? TodayState.upcoming : TodayState.earlier;
}

/// Tasks that run today, in time order.
List<Task> tasksForDay(AppData data, DateTime day) {
  final list = data.tasks.where((t) => t.enabled && t.occursOn(day)).toList()
    ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
  return list;
}
