import '../core/ids.dart';
import 'task.dart';

/// A saved set of recurring tasks that can be applied to the schedule in one tap.
class Routine {
  Routine({
    required this.id,
    required this.name,
    required List<Task> tasks,
    this.builtIn = false,
  }) : tasks = List<Task>.unmodifiable(tasks);

  final String id;
  final String name;
  final List<Task> tasks;
  final bool builtIn;

  /// Snapshot of the recurring tasks in [source] as a new routine.
  factory Routine.snapshot(String name, Iterable<Task> source) {
    final id = newId();
    return Routine(
      id: id,
      name: name,
      tasks: [
        for (final t in source)
          if (!t.isOneOff) t.copyWith(id: newId(), routineId: null),
      ],
    );
  }

  /// Fresh, independent tasks tagged with this routine's id.
  List<Task> instantiate({DateTime? now}) {
    final armed = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return [
      for (final t in tasks)
        Task(
          id: newId(),
          title: t.title,
          minuteOfDay: t.minuteOfDay,
          weekdays: t.weekdays,
          items: t.items,
          routineId: id,
          armedAtMs: armed,
        ),
    ];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'builtIn': builtIn,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: (json['id'] as String?) ?? newId(),
      name: (json['name'] as String?) ?? 'Routine',
      builtIn: (json['builtIn'] as bool?) ?? false,
      tasks: (json['tasks'] as List?)
              ?.whereType<Map>()
              .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <Task>[],
    );
  }
}
