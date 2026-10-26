import '../core/time_utils.dart';
import 'launch_item.dart';
import 'routine.dart';
import 'task.dart';

int _at(int h, int m) => h * 60 + m;

const LaunchItem _vscode = LaunchItem(kind: LaunchKind.app, target: 'code', label: 'VS Code');
const LaunchItem _duolingo = LaunchItem(
  kind: LaunchKind.url,
  target: 'https://www.duolingo.com/learn',
  label: 'Duolingo',
);
const LaunchItem _pomodoro = LaunchItem(
  kind: LaunchKind.url,
  target: 'https://pomofocus.io',
  label: 'Pomodoro timer',
);

Task _t(String id, String title, int minute, Set<int> days, [List<LaunchItem> items = const []]) {
  return Task(id: id, title: title, minuteOfDay: minute, weekdays: days, items: items, armedAtMs: 0);
}

/// Starter routines, added once on first run. Edit or delete them freely.
List<Routine> builtInRoutines() => [
      Routine(
        id: 'builtin-weekday',
        name: 'Weekday Routine',
        builtIn: true,
        tasks: [
          _t('wd1', 'Wake up and stretch', _at(7, 30), kWeekdaysMonFri),
          _t('wd2', 'Breakfast', _at(8, 15), kWeekdaysMonFri),
          _t('wd3', 'Deep work block', _at(9, 0), kWeekdaysMonFri, [_vscode, _pomodoro]),
          _t('wd4', 'Duolingo', _at(11, 0), kWeekdaysMonFri, [_duolingo]),
          _t('wd5', 'Lunch', _at(13, 30), kWeekdaysMonFri),
          _t('wd6', 'Study block', _at(15, 0), kWeekdaysMonFri, [_pomodoro]),
          _t('wd7', 'Workout', _at(18, 30), kWeekdaysMonFri),
          _t('wd8', 'Plan tomorrow', _at(22, 30), kWeekdaysMonFri),
        ],
      ),
      Routine(
        id: 'builtin-exam',
        name: 'Exam Prep Routine',
        builtIn: true,
        tasks: [
          _t('ex1', 'Revision block 1', _at(6, 30), kEveryDay, [_pomodoro]),
          _t('ex2', 'Practice problems', _at(9, 0), kEveryDay, [_pomodoro]),
          _t('ex3', 'Lunch and a short walk', _at(12, 30), kEveryDay),
          _t('ex4', 'Revision block 2', _at(14, 0), kEveryDay, [_pomodoro]),
          _t('ex5', 'Past paper or mock test', _at(17, 0), kEveryDay),
          _t('ex6', 'Review notes', _at(19, 30), kEveryDay),
          _t('ex7', 'Wind down, no screens', _at(22, 0), kEveryDay),
        ],
      ),
      Routine(
        id: 'builtin-weekend',
        name: 'Weekend Routine',
        builtIn: true,
        tasks: [
          _t('we1', 'Slow breakfast', _at(9, 0), kWeekend),
          _t('we2', 'Duolingo', _at(10, 30), kWeekend, [_duolingo]),
          _t('we3', 'Side project', _at(11, 30), kWeekend, [_vscode]),
          _t('we4', 'Lunch', _at(14, 0), kWeekend),
          _t('we5', 'Get outside', _at(16, 0), kWeekend),
          _t('we6', 'Weekly review', _at(20, 0), kWeekend),
        ],
      ),
    ];
