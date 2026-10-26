import '../core/time_utils.dart';
import 'routine.dart';
import 'task.dart';

enum DayStatus { done, skipped, missed }

/// Everything VidHub stores, as one immutable snapshot.
class AppData {
  const AppData({
    this.tasks = const <Task>[],
    this.routines = const <Routine>[],
    this.log = const <String, String>{},
    this.snoozes = const <String, int>{},
    this.seeded = false,
  });

  final List<Task> tasks;
  final List<Routine> routines;

  /// `"taskId|yyyy-MM-dd"` -> [DayStatus.name]
  final Map<String, String> log;

  /// taskId -> epoch millis when the snoozed alert should come back.
  final Map<String, int> snoozes;

  /// True once the built-in routines have been added.
  final bool seeded;

  static String logKey(String taskId, DateTime day) => '$taskId|${dateKey(day)}';

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  DayStatus? statusOf(String taskId, DateTime day) {
    final value = log[logKey(taskId, day)];
    if (value == null) return null;
    for (final s in DayStatus.values) {
      if (s.name == value) return s;
    }
    return null;
  }

  AppData withStatus(String taskId, DateTime day, DayStatus status) {
    return copyWith(log: {...log, logKey(taskId, day): status.name});
  }

  AppData copyWith({
    List<Task>? tasks,
    List<Routine>? routines,
    Map<String, String>? log,
    Map<String, int>? snoozes,
    bool? seeded,
  }) {
    return AppData(
      tasks: tasks ?? this.tasks,
      routines: routines ?? this.routines,
      log: log ?? this.log,
      snoozes: snoozes ?? this.snoozes,
      seeded: seeded ?? this.seeded,
    );
  }

  /// Adds the built-in routines the first time only.
  AppData withSeed(List<Routine> builtIns) {
    if (seeded) return this;
    return copyWith(routines: [...builtIns, ...routines], seeded: true);
  }

  /// Drops old log entries and snoozes that point at deleted tasks.
  AppData pruned(DateTime now, {int keepDays = 60}) {
    final cutoff = dateKey(now.subtract(Duration(days: keepDays)));
    final ids = tasks.map((t) => t.id).toSet();
    final newLog = Map<String, String>.of(log)
      ..removeWhere((key, _) => key.substring(key.lastIndexOf('|') + 1).compareTo(cutoff) < 0);
    final newSnoozes = Map<String, int>.of(snoozes)..removeWhere((id, _) => !ids.contains(id));
    return copyWith(log: newLog, snoozes: newSnoozes);
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'seeded': seeded,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'routines': routines.map((r) => r.toJson()).toList(),
        'log': log,
        'snoozes': snoozes,
      };

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      seeded: (json['seeded'] as bool?) ?? false,
      tasks: (json['tasks'] as List?)
              ?.whereType<Map>()
              .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <Task>[],
      routines: (json['routines'] as List?)
              ?.whereType<Map>()
              .map((e) => Routine.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <Routine>[],
      log: (json['log'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          const <String, String>{},
      snoozes: (json['snoozes'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
          const <String, int>{},
    );
  }
}
