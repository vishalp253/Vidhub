import 'package:flutter_test/flutter_test.dart';
import 'package:vidhub/core/time_utils.dart';
import 'package:vidhub/logic/scheduler.dart';
import 'package:vidhub/logic/today_status.dart';
import 'package:vidhub/models/app_data.dart';
import 'package:vidhub/models/task.dart';

Task task(String id, int h, int m, {Set<int>? days, String? once, bool enabled = true, int armed = 0}) {
  return Task(
    id: id,
    title: id,
    minuteOfDay: h * 60 + m,
    weekdays: days,
    oneOffDate: once,
    enabled: enabled,
    armedAtMs: armed,
  );
}

AppData dataOf(List<Task> tasks, {Map<String, String>? log, Map<String, int>? snoozes}) {
  return AppData(tasks: tasks, log: log ?? const {}, snoozes: snoozes ?? const {});
}

void main() {
  // Saturday 24 Oct 2026
  final sat = DateTime(2026, 10, 24);
  DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 10, 24, h, m, s);

  List<String> dueIds(SchedulerResult r) => [for (final t in r.due) t.id];

  group('firing', () {
    test('nothing before the time', () {
      final r = Scheduler.evaluate(now: at(10, 59, 59), data: dataOf([task('a', 11, 0)]));
      expect(r.isEmpty, isTrue);
    });

    test('fires at the minute and stays due until handled', () {
      final data = dataOf([task('a', 11, 0)]);
      expect(dueIds(Scheduler.evaluate(now: at(11, 0), data: data)), equals(['a']));
      expect(dueIds(Scheduler.evaluate(now: at(11, 20), data: data)), equals(['a']));
    });

    test('does not fire again while its alert is already showing', () {
      final r = Scheduler.evaluate(now: at(11, 1), data: dataOf([task('a', 11, 0)]), active: {'a'});
      expect(r.isEmpty, isTrue);
    });

    test('done, skipped or missed today suppresses it', () {
      for (final s in DayStatus.values) {
        final data = dataOf([task('a', 11, 0)]).withStatus('a', sat, s);
        expect(Scheduler.evaluate(now: at(11, 5), data: data).isEmpty, isTrue);
      }
    });

    test('yesterday\'s status does not suppress today', () {
      final data = dataOf([task('a', 11, 0)]).withStatus('a', sat.subtract(const Duration(days: 1)), DayStatus.done);
      expect(dueIds(Scheduler.evaluate(now: at(11, 5), data: data)), equals(['a']));
    });

    test('disabled tasks never fire', () {
      final r = Scheduler.evaluate(now: at(11, 5), data: dataOf([task('a', 11, 0, enabled: false)]));
      expect(r.isEmpty, isTrue);
    });

    test('earliest first when several are due', () {
      final data = dataOf([task('late', 11, 20), task('early', 11, 5)]);
      expect(dueIds(Scheduler.evaluate(now: at(11, 30), data: data)), equals(['early', 'late']));
    });
  });

  group('grace and missed', () {
    test('30 minutes late still fires', () {
      final r = Scheduler.evaluate(now: at(11, 30, 59), data: dataOf([task('a', 11, 0)]));
      expect(dueIds(r), equals(['a']));
    });

    test('more than 30 minutes late is logged as missed, not alerted', () {
      final r = Scheduler.evaluate(now: at(11, 31, 1), data: dataOf([task('a', 11, 0)]));
      expect(r.due, isEmpty);
      expect(r.missedTaskIds, equals(['a']));
    });
  });

  group('days', () {
    test('weekday-only task does not run on Saturday', () {
      final r = Scheduler.evaluate(now: at(11, 5), data: dataOf([task('a', 11, 0, days: kWeekdaysMonFri)]));
      expect(r.isEmpty, isTrue);
    });

    test('weekend task runs on Saturday', () {
      final r = Scheduler.evaluate(now: at(11, 5), data: dataOf([task('a', 11, 0, days: kWeekend)]));
      expect(dueIds(r), equals(['a']));
    });

    test('one-off only runs on its date', () {
      final data = dataOf([task('a', 11, 0, once: '2026-10-24'), task('b', 11, 0, once: '2026-10-25')]);
      expect(dueIds(Scheduler.evaluate(now: at(11, 5), data: data)), equals(['a']));
    });
  });

  group('armed time', () {
    test('a task created after its time today does not fire or count as missed', () {
      final created = at(9, 40).millisecondsSinceEpoch;
      final data = dataOf([task('a', 9, 0, armed: created)]);
      expect(Scheduler.evaluate(now: at(9, 41), data: data).isEmpty, isTrue);
    });

    test('but fires on the next occurrence', () {
      final created = at(9, 40).millisecondsSinceEpoch;
      final data = dataOf([task('a', 9, 0, armed: created)]);
      final tomorrow = DateTime(2026, 10, 25, 9, 1);
      expect(dueIds(Scheduler.evaluate(now: tomorrow, data: data)), equals(['a']));
    });
  });

  group('snooze', () {
    test('a snoozed task stays quiet until the snooze ends', () {
      final until = at(11, 10).millisecondsSinceEpoch;
      final data = dataOf([task('a', 11, 0)], snoozes: {'a': until});
      expect(Scheduler.evaluate(now: at(11, 5), data: data).isEmpty, isTrue);
      expect(Scheduler.evaluate(now: at(11, 9, 59), data: data).isEmpty, isTrue);
      expect(dueIds(Scheduler.evaluate(now: at(11, 10), data: data)), equals(['a']));
    });

    test('a snooze can outlast the grace period', () {
      final until = at(14, 0).millisecondsSinceEpoch;
      final data = dataOf([task('a', 11, 0)], snoozes: {'a': until});
      expect(dueIds(Scheduler.evaluate(now: at(14, 1), data: data)), equals(['a']));
    });
  });

  group('today status', () {
    test('states', () {
      final t = task('a', 11, 0);
      final plain = dataOf([t]);
      expect(todayState(t, plain, {}, at(10, 0)), equals(TodayState.upcoming));
      expect(todayState(t, plain, {}, at(12, 0)), equals(TodayState.earlier));
      expect(todayState(t, plain, {'a'}, at(11, 1)), equals(TodayState.due));
      expect(todayState(t, dataOf([t], snoozes: {'a': 1}), {}, at(11, 1)), equals(TodayState.snoozed));
      expect(todayState(t, plain.withStatus('a', sat, DayStatus.done), {}, at(11, 1)), equals(TodayState.done));
      expect(todayState(t, plain.withStatus('a', sat, DayStatus.skipped), {}, at(11, 1)), equals(TodayState.skipped));
      expect(todayState(t, plain.withStatus('a', sat, DayStatus.missed), {}, at(12, 1)), equals(TodayState.missed));
    });

    test('tasksForDay filters and sorts', () {
      final data = dataOf([
        task('b', 13, 0),
        task('a', 8, 0),
        task('off', 9, 0, enabled: false),
        task('wk', 10, 0, days: kWeekdaysMonFri),
      ]);
      expect([for (final t in tasksForDay(data, sat)) t.id], equals(['a', 'b']));
    });
  });

  group('time helpers', () {
    test('formatMinuteOfDay', () {
      expect(formatMinuteOfDay(0), equals('12:00 AM'));
      expect(formatMinuteOfDay(5), equals('12:05 AM'));
      expect(formatMinuteOfDay(11 * 60), equals('11:00 AM'));
      expect(formatMinuteOfDay(12 * 60), equals('12:00 PM'));
      expect(formatMinuteOfDay(13 * 60 + 30), equals('1:30 PM'));
      expect(formatMinuteOfDay(23 * 60 + 59), equals('11:59 PM'));
    });

    test('describeWeekdays', () {
      expect(describeWeekdays(kEveryDay), equals('Every day'));
      expect(describeWeekdays(kWeekdaysMonFri), equals('Weekdays'));
      expect(describeWeekdays(kWeekend), equals('Weekends'));
      expect(describeWeekdays({1, 3}), equals('Mon, Wed'));
    });

    test('friendlyDate and longDate', () {
      expect(friendlyDate(sat, sat), equals('Today'));
      expect(friendlyDate(DateTime(2026, 10, 25), sat), equals('Tomorrow'));
      expect(friendlyDate(DateTime(2026, 10, 30), sat), equals('Fri 30 Oct'));
      expect(longDate(sat), equals('Saturday, 24 October'));
    });

    test('dateKey round trip', () {
      expect(dateKey(DateTime(2026, 3, 5)), equals('2026-03-05'));
      expect(parseDateKey('2026-03-05'), equals(DateTime(2026, 3, 5)));
    });
  });
}
