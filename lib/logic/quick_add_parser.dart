import '../core/time_utils.dart';
import '../models/launch_item.dart';

/// Result of parsing the quick-add box.
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    required this.minuteOfDay,
    required this.date,
    required this.items,
    required this.daily,
  });

  final String title;
  final int minuteOfDay;

  /// Local date of the (first) occurrence, time part zero.
  final DateTime date;
  final List<LaunchItem> items;

  /// True when the input started with "daily" or "every day".
  final bool daily;

  /// One-line preview, e.g. "Today · 11:00 AM · Duolingo · 1 link".
  String summary(DateTime now) {
    final when = daily ? 'Every day' : friendlyDate(date, now);
    final parts = <String>[when, formatMinuteOfDay(minuteOfDay), title];
    if (items.isNotEmpty) parts.add(items.length == 1 ? '1 link' : '${items.length} links');
    return parts.join(' · ');
  }
}

final RegExp _dailyPrefix = RegExp(r'^(?:daily|every\s*day)\s+', caseSensitive: false);

final RegExp _relative = RegExp(
  r'^\+\s*(\d{1,4})\s*(m|min|mins|minutes?|h|hr|hrs|hours?)?$',
  caseSensitive: false,
);

final RegExp _clock = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$', caseSensitive: false);

// "11:00 AM gym", "5pm gym", "17:30 gym", "+30m stretch"
final RegExp _leadingTime = RegExp(
  r'^(\+\s*\d{1,4}\s*(?:minutes?|mins?|hours?|hrs?|h|m)?|\d{1,2}(?::\d{2})?\s*(?:am|pm)|\d{1,2}:\d{2})\s+(\S.*)$',
  caseSensitive: false,
  dotAll: true,
);

final RegExp _linkWord = RegExp(r'^(?:[A-Za-z][A-Za-z0-9+.\-]*://\S+|www\.\S+)$');

/// Turns text like these into a task:
///
///   `11:00 AM | Duolingo`
///   `11:00 AM | Duolingo | duolingo.com | C:\Tools\app.exe`
///   `5pm gym`          `17:30 gym`         `+30m stretch`
///   `daily 7am | Wake up`
///
/// A time already passed today means tomorrow. Returns null if the text can't
/// be understood.
QuickAddResult? parseQuickAdd(String input, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  var text = input.trim();
  if (text.isEmpty) return null;

  var daily = false;
  final dailyMatch = _dailyPrefix.firstMatch(text);
  if (dailyMatch != null) {
    daily = true;
    text = text.substring(dailyMatch.end).trimLeft();
  }

  late final (int, DateTime) when;
  var title = '';
  final items = <LaunchItem>[];

  if (text.contains('|')) {
    final parts = text.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return null;
    final resolved = _resolveTime(parts[0], clock, allowBareHour: true);
    if (resolved == null) return null;
    when = resolved;
    title = parts[1];
    for (final raw in parts.skip(2)) {
      items.add(LaunchItem.guess(raw));
    }
  } else {
    final match = _leadingTime.firstMatch(text);
    if (match == null) return null;
    final resolved = _resolveTime(match.group(1)!, clock, allowBareHour: false);
    if (resolved == null) return null;
    when = resolved;
    final titleWords = <String>[];
    for (final word in match.group(2)!.trim().split(RegExp(r'\s+'))) {
      if (_linkWord.hasMatch(word)) {
        items.add(LaunchItem.guess(word));
      } else {
        titleWords.add(word);
      }
    }
    title = titleWords.join(' ');
    if (title.isEmpty && items.isNotEmpty) title = items.first.displayName;
  }

  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) return null;
  if (title.length > 120) title = title.substring(0, 120).trimRight();

  return QuickAddResult(
    title: title,
    minuteOfDay: when.$1,
    date: when.$2,
    items: items,
    daily: daily,
  );
}

(int, DateTime)? _resolveTime(String raw, DateTime now, {required bool allowBareHour}) {
  final t = raw.trim();

  final rel = _relative.firstMatch(t);
  if (rel != null) {
    final n = int.parse(rel.group(1)!);
    final unit = (rel.group(2) ?? 'm').toLowerCase();
    final minutes = unit.startsWith('h') ? n * 60 : n;
    if (minutes <= 0 || minutes > 24 * 60) return null;
    final target = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(Duration(minutes: minutes));
    return (target.hour * 60 + target.minute, dateOnly(target));
  }

  final m = _clock.firstMatch(t);
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = m.group(2) == null ? 0 : int.parse(m.group(2)!);
  final suffix = m.group(3)?.toLowerCase();
  if (minute > 59) return null;

  if (suffix != null) {
    if (hour < 1 || hour > 12) return null;
    if (suffix == 'pm' && hour != 12) hour += 12;
    if (suffix == 'am' && hour == 12) hour = 0;
  } else {
    if (hour > 23) return null;
    if (m.group(2) == null && !allowBareHour) return null;
  }

  final minuteOfDay = hour * 60 + minute;
  final today = dateOnly(now);
  final scheduled = atMinute(today, minuteOfDay);
  final date = scheduled.isAfter(now) ? today : DateTime(today.year, today.month, today.day + 1);
  return (minuteOfDay, date);
}
