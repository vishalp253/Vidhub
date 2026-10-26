import 'package:flutter_test/flutter_test.dart';
import 'package:vidhub/logic/quick_add_parser.dart';
import 'package:vidhub/models/launch_item.dart';

void main() {
  // Saturday 24 Oct 2026, 10:00:30
  final now = DateTime(2026, 10, 24, 10, 0, 30);

  group('pipe format', () {
    test('11:00 AM | Duolingo, later today', () {
      final r = parseQuickAdd('11:00 AM | Duolingo', now: now)!;
      expect(r.title, equals('Duolingo'));
      expect(r.minuteOfDay, equals(11 * 60));
      expect(r.date, equals(DateTime(2026, 10, 24)));
      expect(r.daily, isFalse);
      expect(r.items, isEmpty);
    });

    test('time already passed means tomorrow', () {
      final r = parseQuickAdd('9:30 AM | Standup', now: now)!;
      expect(r.date, equals(DateTime(2026, 10, 25)));
      expect(r.minuteOfDay, equals(9 * 60 + 30));
    });

    test('exactly now means tomorrow', () {
      final r = parseQuickAdd('10:00 | Right now', now: DateTime(2026, 10, 24, 10, 0, 0))!;
      expect(r.date, equals(DateTime(2026, 10, 25)));
    });

    test('bare hour is accepted with a pipe', () {
      final r = parseQuickAdd('11 | Duolingo', now: now)!;
      expect(r.minuteOfDay, equals(11 * 60));
    });

    test('12 AM is midnight and 12 PM is noon', () {
      expect(parseQuickAdd('12:00 AM | Midnight', now: now)!.minuteOfDay, equals(0));
      expect(parseQuickAdd('12:00 PM | Noon', now: now)!.minuteOfDay, equals(12 * 60));
    });

    test('extra segments become launch items', () {
      final r = parseQuickAdd(r'11:00 AM | Duolingo | duolingo.com | C:\Tools\app.exe | code', now: now)!;
      expect(r.items.length, equals(3));
      expect(r.items[0], equals(const LaunchItem(kind: LaunchKind.url, target: 'https://duolingo.com')));
      expect(r.items[1].kind, equals(LaunchKind.app));
      expect(r.items[2].target, equals('code'));
    });

    test('rejects bad times and missing titles', () {
      expect(parseQuickAdd('25:00 | Nope', now: now), isNull);
      expect(parseQuickAdd('13 PM | Nope', now: now), isNull);
      expect(parseQuickAdd('11:75 | Nope', now: now), isNull);
      expect(parseQuickAdd('11:00 |', now: now), isNull);
      expect(parseQuickAdd('lunch | 11:00', now: now), isNull);
    });
  });

  group('free-form', () {
    test('5pm gym', () {
      final r = parseQuickAdd('5pm gym', now: now)!;
      expect(r.title, equals('gym'));
      expect(r.minuteOfDay, equals(17 * 60));
      expect(r.date, equals(DateTime(2026, 10, 24)));
    });

    test('5 pm with a space, and 24-hour time', () {
      expect(parseQuickAdd('5 pm gym', now: now)!.minuteOfDay, equals(17 * 60));
      expect(parseQuickAdd('17:30 gym', now: now)!.minuteOfDay, equals(17 * 60 + 30));
    });

    test('11:00 AM Duolingo without a pipe', () {
      final r = parseQuickAdd('11:00 AM Duolingo', now: now)!;
      expect(r.title, equals('Duolingo'));
      expect(r.minuteOfDay, equals(11 * 60));
    });

    test('a bare number without am/pm is not a time', () {
      expect(parseQuickAdd('5 gym', now: now), isNull);
    });

    test('links in the text become launch items', () {
      final r = parseQuickAdd('11:00 AM Duolingo https://www.duolingo.com/learn', now: now)!;
      expect(r.title, equals('Duolingo'));
      expect(r.items.length, equals(1));
      expect(r.items.first.target, equals('https://www.duolingo.com/learn'));
    });

    test('a link alone supplies the title', () {
      final r = parseQuickAdd('11am https://www.duolingo.com', now: now)!;
      expect(r.title, equals('duolingo.com'));
    });
  });

  group('relative', () {
    test('+30m', () {
      final r = parseQuickAdd('+30m stretch', now: now)!;
      expect(r.title, equals('stretch'));
      expect(r.minuteOfDay, equals(10 * 60 + 30));
      expect(r.date, equals(DateTime(2026, 10, 24)));
    });

    test('+1h and spelled-out units', () {
      expect(parseQuickAdd('+1h read', now: now)!.minuteOfDay, equals(11 * 60));
      expect(parseQuickAdd('+45 min walk', now: now)!.minuteOfDay, equals(10 * 60 + 45));
      expect(parseQuickAdd('+2 hours nap', now: now)!.minuteOfDay, equals(12 * 60));
    });

    test('rolls over midnight', () {
      final late = DateTime(2026, 10, 24, 23, 40);
      final r = parseQuickAdd('+30m sleep', now: late)!;
      expect(r.minuteOfDay, equals(10));
      expect(r.date, equals(DateTime(2026, 10, 25)));
    });

    test('works inside a pipe too', () {
      final r = parseQuickAdd('+15m | Tea', now: now)!;
      expect(r.minuteOfDay, equals(10 * 60 + 15));
    });
  });

  group('daily', () {
    test('daily prefix', () {
      final r = parseQuickAdd('daily 7am | Wake up', now: now)!;
      expect(r.daily, isTrue);
      expect(r.title, equals('Wake up'));
      expect(r.minuteOfDay, equals(7 * 60));
    });

    test('every day prefix, free-form', () {
      final r = parseQuickAdd('every day 7am wake up', now: now)!;
      expect(r.daily, isTrue);
      expect(r.title, equals('wake up'));
    });
  });

  group('summary', () {
    test('describes what will be created', () {
      final r = parseQuickAdd('11:00 AM | Duolingo | duolingo.com', now: now)!;
      expect(r.summary(now), equals('Today · 11:00 AM · Duolingo · 1 link'));
      final d = parseQuickAdd('daily 7am | Wake up', now: now)!;
      expect(d.summary(now), equals('Every day · 7:00 AM · Wake up'));
      final t = parseQuickAdd('9am | Standup', now: now)!;
      expect(t.summary(now), equals('Tomorrow · 9:00 AM · Standup'));
    });
  });

  test('empty and nonsense input', () {
    expect(parseQuickAdd('', now: now), isNull);
    expect(parseQuickAdd('   ', now: now), isNull);
    expect(parseQuickAdd('hello world', now: now), isNull);
  });
}
