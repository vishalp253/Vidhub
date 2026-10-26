const List<String> kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> kWeekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> kMonthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// ISO weekday numbers: 1 = Monday ... 7 = Sunday.
const Set<int> kEveryDay = {1, 2, 3, 4, 5, 6, 7};
const Set<int> kWeekdaysMonFri = {1, 2, 3, 4, 5};
const Set<int> kWeekend = {6, 7};

String two(int n) => n.toString().padLeft(2, '0');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-MM-dd` in local time.
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

/// Inverse of [dateKey]. Throws [FormatException] on bad input.
DateTime parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) throw FormatException('Bad date key', key);
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

DateTime atMinute(DateTime day, int minuteOfDay) =>
    DateTime(day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);

/// 0..1439 -> "11:05 AM"
String formatMinuteOfDay(int minuteOfDay) {
  final h24 = minuteOfDay ~/ 60;
  final m = minuteOfDay % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final suffix = h24 < 12 ? 'AM' : 'PM';
  return '$h12:${two(m)} $suffix';
}

String describeWeekdays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.containsAll(kWeekdaysMonFri)) return 'Weekdays';
  if (days.length == 2 && days.containsAll(kWeekend)) return 'Weekends';
  final sorted = days.toList()..sort();
  return sorted.map((d) => kWeekdayShort[d - 1]).join(', ');
}

String friendlyDate(DateTime date, DateTime now) {
  final d = dateOnly(date);
  final t = dateOnly(now);
  final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${kWeekdayShort[d.weekday - 1]} ${d.day} ${kMonthShort[d.month - 1]}';
}

/// "Saturday, 24 October"
String longDate(DateTime d) => '${kWeekdayLong[d.weekday - 1]}, ${d.day} ${kMonthLong[d.month - 1]}';
