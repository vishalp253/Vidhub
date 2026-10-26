import '../core/ids.dart';
import '../core/time_utils.dart';
import 'launch_item.dart';

/// One scheduled block of the day.
///
/// A task either repeats on [weekdays] (ISO 1=Mon..7=Sun) or, when [oneOffDate]
/// is set, happens once on that date.
class Task {
  Task({
    required this.id,
    required this.title,
    required this.minuteOfDay,
    Set<int>? weekdays,
    this.oneOffDate,
    List<LaunchItem>? items,
    this.enabled = true,
    this.routineId,
    int? armedAtMs,
  })  : weekdays = Set<int>.unmodifiable(weekdays ?? kEveryDay),
        items = List<LaunchItem>.unmodifiable(items ?? const <LaunchItem>[]),
        armedAtMs = armedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  final String title;

  /// Minutes after local midnight, 0..1439.
  final int minuteOfDay;
  final Set<int> weekdays;

  /// `yyyy-MM-dd` when this is a one-time task, otherwise null.
  final String? oneOffDate;
  final List<LaunchItem> items;
  final bool enabled;

  /// Set when the task came from applying a routine.
  final String? routineId;

  /// Occurrences scheduled before this moment never fire. Stops a task you
  /// create at 9:40 for "9:00" from going off, or from being logged as missed.
  final int armedAtMs;

  bool get isOneOff => oneOffDate != null;
  String get timeLabel => formatMinuteOfDay(minuteOfDay);

  bool occursOn(DateTime day) {
    if (oneOffDate != null) return oneOffDate == dateKey(day);
    return weekdays.contains(day.weekday);
  }

  static const Object _keep = Object();

  Task copyWith({
    String? id,
    String? title,
    int? minuteOfDay,
    Set<int>? weekdays,
    Object? oneOffDate = _keep,
    List<LaunchItem>? items,
    bool? enabled,
    Object? routineId = _keep,
    int? armedAtMs,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      weekdays: weekdays ?? this.weekdays,
      oneOffDate: identical(oneOffDate, _keep) ? this.oneOffDate : oneOffDate as String?,
      items: items ?? this.items,
      enabled: enabled ?? this.enabled,
      routineId: identical(routineId, _keep) ? this.routineId : routineId as String?,
      armedAtMs: armedAtMs ?? this.armedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'minuteOfDay': minuteOfDay,
        'weekdays': (weekdays.toList()..sort()),
        if (oneOffDate != null) 'oneOffDate': oneOffDate,
        'items': items.map((i) => i.toJson()).toList(),
        'enabled': enabled,
        if (routineId != null) 'routineId': routineId,
        'armedAtMs': armedAtMs,
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['weekdays'] as List?)?.whereType<int>().where((d) => d >= 1 && d <= 7).toSet();
    final minute = ((json['minuteOfDay'] as num?)?.toInt() ?? 0).clamp(0, 1439);
    return Task(
      id: (json['id'] as String?) ?? newId(),
      title: (json['title'] as String?) ?? 'Untitled',
      minuteOfDay: minute,
      weekdays: (rawDays == null || rawDays.isEmpty) ? kEveryDay : rawDays,
      oneOffDate: json['oneOffDate'] as String?,
      items: (json['items'] as List?)
              ?.whereType<Map>()
              .map((e) => LaunchItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <LaunchItem>[],
      enabled: (json['enabled'] as bool?) ?? true,
      routineId: json['routineId'] as String?,
      armedAtMs: (json['armedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
