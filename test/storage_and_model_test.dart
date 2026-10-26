import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidhub/core/time_utils.dart';
import 'package:vidhub/models/app_data.dart';
import 'package:vidhub/models/launch_item.dart';
import 'package:vidhub/models/routine.dart';
import 'package:vidhub/models/seed_data.dart';
import 'package:vidhub/models/task.dart';
import 'package:vidhub/services/storage_service.dart';

Future<void> withTempDir(Future<void> Function(Directory dir) body) async {
  final dir = await Directory.systemTemp.createTemp('vidhub_test_');
  try {
    await body(dir);
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  group('models', () {
    test('Task JSON round trip keeps everything', () {
      final t = Task(
        id: 't1',
        title: 'Duolingo',
        minuteOfDay: 11 * 60,
        weekdays: {1, 3, 5},
        items: const [LaunchItem(kind: LaunchKind.url, target: 'https://duolingo.com', label: 'Duo')],
        enabled: false,
        routineId: 'r1',
        armedAtMs: 123,
      );
      final back = Task.fromJson(t.toJson());
      expect(back.id, equals('t1'));
      expect(back.title, equals('Duolingo'));
      expect(back.minuteOfDay, equals(660));
      expect(back.weekdays, equals({1, 3, 5}));
      expect(back.items, equals(t.items));
      expect(back.enabled, isFalse);
      expect(back.routineId, equals('r1'));
      expect(back.armedAtMs, equals(123));
      expect(back.oneOffDate, isNull);
    });

    test('Task.fromJson survives junk', () {
      final t = Task.fromJson({'minuteOfDay': 99999, 'weekdays': [0, 9, 'x']});
      expect(t.minuteOfDay, equals(1439));
      expect(t.weekdays, equals(kEveryDay));
      expect(t.title, equals('Untitled'));
    });

    test('copyWith can clear nullable fields', () {
      final once = Task(id: 'a', title: 'x', minuteOfDay: 0, oneOffDate: '2026-10-24', routineId: 'r');
      final repeat = once.copyWith(oneOffDate: null, routineId: null);
      expect(repeat.oneOffDate, isNull);
      expect(repeat.routineId, isNull);
      expect(once.copyWith(title: 'y').oneOffDate, equals('2026-10-24'));
    });

    test('occursOn', () {
      final weekdays = Task(id: 'a', title: 'x', minuteOfDay: 0, weekdays: kWeekdaysMonFri);
      expect(weekdays.occursOn(DateTime(2026, 10, 23)), isTrue); // Friday
      expect(weekdays.occursOn(DateTime(2026, 10, 24)), isFalse); // Saturday
      final once = Task(id: 'b', title: 'x', minuteOfDay: 0, oneOffDate: '2026-10-24');
      expect(once.occursOn(DateTime(2026, 10, 24, 23, 59)), isTrue);
      expect(once.occursOn(DateTime(2026, 10, 25)), isFalse);
    });

    test('Routine.instantiate makes fresh independent tasks tagged with the routine', () {
      final routine = builtInRoutines().first;
      final a = routine.instantiate();
      final b = routine.instantiate();
      expect(a.length, equals(routine.tasks.length));
      expect(a.every((t) => t.routineId == routine.id), isTrue);
      expect(a.first.id == b.first.id, isFalse);
      expect(a.first.id == routine.tasks.first.id, isFalse);
    });

    test('Routine.snapshot keeps recurring tasks only', () {
      final r = Routine.snapshot('Mine', [
        Task(id: '1', title: 'Daily', minuteOfDay: 60),
        Task(id: '2', title: 'Once', minuteOfDay: 120, oneOffDate: '2026-10-24'),
      ]);
      expect(r.tasks.length, equals(1));
      expect(r.tasks.first.title, equals('Daily'));
      expect(r.builtIn, isFalse);
    });

    test('built-in routines are sane', () {
      final routines = builtInRoutines();
      expect([for (final r in routines) r.name], equals(['Weekday Routine', 'Exam Prep Routine', 'Weekend Routine']));
      for (final r in routines) {
        expect(r.tasks.isNotEmpty, isTrue);
        final ids = r.tasks.map((t) => t.id).toSet();
        expect(ids.length, equals(r.tasks.length));
      }
    });

    test('AppData.withSeed only seeds once', () {
      final once = const AppData().withSeed(builtInRoutines());
      expect(once.routines.length, equals(3));
      expect(once.seeded, isTrue);
      final deleted = once.copyWith(routines: const <Routine>[]);
      expect(deleted.withSeed(builtInRoutines()).routines, isEmpty);
    });

    test('AppData.pruned drops old log entries and orphan snoozes', () {
      final now = DateTime(2026, 10, 24);
      final data = AppData(
        tasks: [Task(id: 'a', title: 'x', minuteOfDay: 0)],
        log: {
          'a|2026-10-23': 'done',
          'a|2026-01-01': 'done',
        },
        snoozes: {'a': 1, 'gone': 2},
      ).pruned(now);
      expect(data.log.keys.toList(), equals(['a|2026-10-23']));
      expect(data.snoozes.keys.toList(), equals(['a']));
    });

    test('AppData JSON round trip', () {
      final data = const AppData().withSeed(builtInRoutines()).copyWith(
        tasks: [Task(id: 'a', title: 'x', minuteOfDay: 30)],
        log: {'a|2026-10-24': 'skipped'},
        snoozes: {'a': 42},
      );
      final back = AppData.fromJson(data.toJson());
      expect(back.tasks.length, equals(1));
      expect(back.routines.length, equals(3));
      expect(back.log, equals({'a|2026-10-24': 'skipped'}));
      expect(back.snoozes, equals({'a': 42}));
      expect(back.seeded, isTrue);
      expect(back.statusOf('a', DateTime(2026, 10, 24)), equals(DayStatus.skipped));
    });
  });

  group('storage', () {
    test('a missing file loads as empty', () async {
      await withTempDir((dir) async {
        final s = StorageService(File('${dir.path}/data.json'));
        final data = await s.load();
        expect(data.tasks, isEmpty);
        expect(data.seeded, isFalse);
      });
    });

    test('save then load round trips', () async {
      await withTempDir((dir) async {
        final file = File('${dir.path}/nested/data.json');
        final s = StorageService(file);
        await s.save(AppData(tasks: [Task(id: 'a', title: 'Hello', minuteOfDay: 90)], seeded: true));
        final back = await StorageService(file).load();
        expect(back.tasks.single.title, equals('Hello'));
        expect(back.seeded, isTrue);
        expect(File('${file.path}.tmp').existsSync(), isFalse);
      });
    });

    test('many quick saves end with the last one', () async {
      await withTempDir((dir) async {
        final file = File('${dir.path}/data.json');
        final s = StorageService(file);
        for (var i = 0; i < 25; i++) {
          s.save(AppData(tasks: [Task(id: 'a', title: 'v$i', minuteOfDay: i)]));
        }
        await s.save(const AppData(tasks: <Task>[]).copyWith(tasks: [Task(id: 'a', title: 'last', minuteOfDay: 1)]));
        final back = await StorageService(file).load();
        expect(back.tasks.single.title, equals('last'));
      });
    });

    test('a corrupt file is set aside, not overwritten', () async {
      await withTempDir((dir) async {
        final file = File('${dir.path}/data.json');
        await file.writeAsString('{ this is not json');
        final errors = <Object>[];
        final s = StorageService(file, onError: errors.add);
        final data = await s.load();
        expect(data.tasks, isEmpty);
        expect(errors.length, equals(1));
        expect(file.existsSync(), isFalse);
        final saved = dir.listSync().where((e) => e.path.contains('.corrupt-')).toList();
        expect(saved.length, equals(1));
        expect(File(saved.single.path).readAsStringSync(), equals('{ this is not json'));
      });
    });

    test('valid JSON of the wrong shape is also set aside', () async {
      await withTempDir((dir) async {
        final file = File('${dir.path}/data.json');
        await file.writeAsString('[1,2,3]');
        final data = await StorageService(file).load();
        expect(data.tasks, isEmpty);
        expect(file.existsSync(), isFalse);
      });
    });
  });
}
