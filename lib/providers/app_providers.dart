import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ids.dart';
import '../core/time_utils.dart';
import '../logic/quick_add_parser.dart';
import '../logic/scheduler.dart';
import '../models/app_data.dart';
import '../models/routine.dart';
import '../models/task.dart';
import '../services/launcher_service.dart';
import '../services/storage_service.dart';
import '../services/window_service.dart';

// ---------------------------------------------------------------------------
// Values supplied by main() before the UI starts
// ---------------------------------------------------------------------------

final initialDataProvider = Provider<AppData>(
  (ref) => throw UnimplementedError('initialDataProvider must be overridden in main()'),
);
final storageProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageProvider must be overridden in main()'),
);
final windowServiceProvider = Provider<WindowService>(
  (ref) => throw UnimplementedError('windowServiceProvider must be overridden in main()'),
);
final initialWindowModeProvider = Provider<WindowMode>((ref) => WindowMode.manager);

final launcherProvider = Provider<LauncherService>((ref) => LauncherService());

/// Fully shuts the app down (tray icon, hotkey, window). Supplied by main().
final quitProvider = Provider<Future<void> Function()>(
  (ref) => throw UnimplementedError('quitProvider must be overridden in main()'),
);

/// Ticks so "upcoming / earlier" labels stay current while the app is open.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(const Duration(seconds: 15), (_) => DateTime.now());
});

// ---------------------------------------------------------------------------
// Small state holders
// ---------------------------------------------------------------------------

/// null = not tried yet, true = Ctrl+Shift+T registered, false = failed.
class HotkeyStatus extends Notifier<bool?> {
  @override
  bool? build() => null;
  void set(bool? value) => state = value;
}

final hotkeyStatusProvider = NotifierProvider<HotkeyStatus, bool?>(HotkeyStatus.new);

/// Last "couldn't open ..." message from the alert card, if any.
class LaunchError extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? message) => state = message;
}

final launchErrorProvider = NotifierProvider<LaunchError, String?>(LaunchError.new);

/// Ids of tasks whose alert is currently showing, oldest first.
class AlertQueue extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  void enqueue(Iterable<String> ids) {
    final next = [...state];
    for (final id in ids) {
      if (!next.contains(id)) next.add(id);
    }
    if (next.length != state.length) state = next;
  }

  void remove(String id) {
    if (state.contains(id)) state = state.where((e) => e != id).toList();
  }
}

final alertQueueProvider = NotifierProvider<AlertQueue, List<String>>(AlertQueue.new);

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class AppController extends Notifier<AppData> {
  @override
  AppData build() => ref.read(initialDataProvider);

  void _commit(AppData next) {
    state = next;
    ref.read(storageProvider).save(next);
  }

  void addTask(Task task) => _commit(state.copyWith(tasks: [...state.tasks, task]));

  /// Builds and stores a task from parsed quick-add text.
  Task addFromQuickAdd(QuickAddResult r) {
    final task = Task(
      id: newId(),
      title: r.title,
      minuteOfDay: r.minuteOfDay,
      weekdays: kEveryDay,
      oneOffDate: r.daily ? null : dateKey(r.date),
      items: r.items,
    );
    addTask(task);
    return task;
  }

  void updateTask(Task updated) {
    final old = state.taskById(updated.id);
    if (old == null) return;

    final rescheduled = old.minuteOfDay != updated.minuteOfDay ||
        old.oneOffDate != updated.oneOffDate ||
        old.weekdays.length != updated.weekdays.length ||
        !old.weekdays.containsAll(updated.weekdays);

    var next = updated;
    var log = state.log;
    var snoozes = state.snoozes;
    if (rescheduled) {
      // A new time means a fresh start: forget today's result and any snooze,
      // and don't fire for a time that is already behind us.
      next = updated.copyWith(armedAtMs: DateTime.now().millisecondsSinceEpoch);
      log = Map<String, String>.of(log)..remove(AppData.logKey(updated.id, DateTime.now()));
      snoozes = Map<String, int>.of(snoozes)..remove(updated.id);
      ref.read(alertQueueProvider.notifier).remove(updated.id);
    }
    _commit(state.copyWith(
      tasks: [for (final t in state.tasks) t.id == updated.id ? next : t],
      log: log,
      snoozes: snoozes,
    ));
    if (rescheduled) ref.read(windowModeProvider.notifier).afterAlertChange();
  }

  void deleteTask(String id) {
    final snoozes = Map<String, int>.of(state.snoozes)..remove(id);
    _commit(state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList(), snoozes: snoozes));
    ref.read(alertQueueProvider.notifier).remove(id);
    ref.read(windowModeProvider.notifier).afterAlertChange();
  }

  void setEnabled(String id, bool enabled) {
    _commit(state.copyWith(
      tasks: [for (final t in state.tasks) t.id == id ? t.copyWith(enabled: enabled) : t],
    ));
    if (!enabled) {
      ref.read(alertQueueProvider.notifier).remove(id);
      ref.read(windowModeProvider.notifier).afterAlertChange();
    }
  }

  /// Records today's outcome for a task and clears any snooze.
  void resolve(String taskId, DayStatus status, {DateTime? now}) {
    final when = now ?? DateTime.now();
    final snoozes = Map<String, int>.of(state.snoozes)..remove(taskId);
    _commit(state.withStatus(taskId, when, status).copyWith(snoozes: snoozes));
  }

  void markMissed(List<String> taskIds, DateTime now) {
    var next = state;
    for (final id in taskIds) {
      next = next.withStatus(id, now, DayStatus.missed);
    }
    _commit(next);
  }

  void snooze(String taskId, {int minutes = 10, DateTime? now}) {
    final until = (now ?? DateTime.now()).add(Duration(minutes: minutes)).millisecondsSinceEpoch;
    _commit(state.copyWith(snoozes: {...state.snoozes, taskId: until}));
  }

  /// Replaces every task that came from a routine with [routine]'s tasks.
  /// Tasks you added yourself are kept. Returns how many tasks were added.
  int applyRoutine(Routine routine) {
    final removed = state.tasks.where((t) => t.routineId != null).map((t) => t.id).toSet();
    final kept = state.tasks.where((t) => t.routineId == null).toList();
    final added = routine.instantiate();
    final snoozes = Map<String, int>.of(state.snoozes)..removeWhere((id, _) => removed.contains(id));
    _commit(state.copyWith(tasks: [...kept, ...added], snoozes: snoozes));
    for (final id in removed) {
      ref.read(alertQueueProvider.notifier).remove(id);
    }
    ref.read(windowModeProvider.notifier).afterAlertChange();
    return added.length;
  }

  /// Saves the current recurring tasks as a new routine. Null if there are none.
  Routine? saveRoutine(String name) {
    final routine = Routine.snapshot(name, state.tasks);
    if (routine.tasks.isEmpty) return null;
    _commit(state.copyWith(routines: [...state.routines, routine]));
    return routine;
  }

  void deleteRoutine(String id) {
    _commit(state.copyWith(routines: state.routines.where((r) => r.id != id).toList()));
  }
}

final appControllerProvider = NotifierProvider<AppController, AppData>(AppController.new);

// ---------------------------------------------------------------------------
// Alert buttons
// ---------------------------------------------------------------------------

/// What the Done / Snooze / Skip / Open buttons do.
class AlertActions {
  AlertActions(this._ref);

  final Ref _ref;

  void done(String id) => _finish(id, DayStatus.done);
  void skip(String id) => _finish(id, DayStatus.skipped);

  void snooze(String id, {int minutes = 10}) {
    _ref.read(appControllerProvider.notifier).snooze(id, minutes: minutes);
    _afterRemoved(id);
  }

  /// Opens every link, program and file attached to the task. The alert stays
  /// on screen: opening something is not the same as having done it.
  Future<void> open(String id) async {
    final task = _ref.read(appControllerProvider).taskById(id);
    if (task == null || task.items.isEmpty) return;
    _ref.read(launchErrorProvider.notifier).set(null);
    final results = await _ref.read(launcherProvider).launchAll(task.items);
    final failed = results.where((r) => !r.ok).toList();
    if (failed.isNotEmpty) {
      _ref.read(launchErrorProvider.notifier).set(failed.first.error);
    }
  }

  /// Drops alerts whose task was deleted or disabled.
  void sweep() {
    final data = _ref.read(appControllerProvider);
    final queue = _ref.read(alertQueueProvider);
    for (final id in queue) {
      final t = data.taskById(id);
      if (t == null || !t.enabled) _ref.read(alertQueueProvider.notifier).remove(id);
    }
    _ref.read(windowModeProvider.notifier).afterAlertChange();
  }

  void _finish(String id, DayStatus status) {
    _ref.read(appControllerProvider.notifier).resolve(id, status);
    _afterRemoved(id);
  }

  void _afterRemoved(String id) {
    _ref.read(launchErrorProvider.notifier).set(null);
    _ref.read(alertQueueProvider.notifier).remove(id);
    _ref.read(windowModeProvider.notifier).afterAlertChange();
  }
}

final alertActionsProvider = Provider<AlertActions>((ref) => AlertActions(ref));

// ---------------------------------------------------------------------------
// Which role the one native window is playing
// ---------------------------------------------------------------------------

class WindowModeController extends Notifier<WindowMode> {
  Future<void> _chain = Future<void>.value();
  DateTime _shownAt = DateTime.fromMillisecondsSinceEpoch(0);
  WindowMode _returnTo = WindowMode.hidden;

  @override
  WindowMode build() => ref.read(initialWindowModeProvider);

  /// Switches mode. Calls are queued so two quick triggers can't fight over
  /// the window.
  Future<void> go(WindowMode next) {
    final run = _chain.then((_) => _go(next));
    _chain = run.catchError((Object e) {
      debugPrint('VidHub: window change failed: $e');
    });
    return run;
  }

  Future<void> _go(WindowMode next) async {
    final svc = ref.read(windowServiceProvider);
    if (next == WindowMode.hidden) {
      await svc.hide();
      state = next;
      return;
    }
    await svc.prepare(next); // size, position, flags while still hidden
    state = next; // swap the UI
    await Future<void>.delayed(const Duration(milliseconds: 60)); // let it paint
    await svc.reveal(next);
    _shownAt = DateTime.now();
  }

  Future<void> openManager() async {
    if (state == WindowMode.manager) {
      await ref.read(windowServiceProvider).reveal(WindowMode.manager);
      return;
    }
    await go(WindowMode.manager);
  }

  Future<void> openQuickAdd() async {
    if (state == WindowMode.quickAdd) {
      await ref.read(windowServiceProvider).reveal(WindowMode.quickAdd);
      return;
    }
    _returnTo = state == WindowMode.manager ? WindowMode.manager : WindowMode.hidden;
    await go(WindowMode.quickAdd);
  }

  /// Leaves the current mode: back to alerts if any are waiting, otherwise to
  /// wherever quick-add was opened from, otherwise out of sight.
  Future<void> closeTransient() {
    if (ref.read(alertQueueProvider).isNotEmpty) return go(WindowMode.overlay);
    if (state == WindowMode.quickAdd && _returnTo == WindowMode.manager) {
      _returnTo = WindowMode.hidden;
      return go(WindowMode.manager);
    }
    return go(WindowMode.hidden);
  }

  /// A new alert is due. Show it, unless the user is actively inside the
  /// manager, where it appears as a banner instead.
  Future<void> onAlertsArrived() async {
    if (state == WindowMode.overlay || state == WindowMode.quickAdd) return;
    if (state == WindowMode.manager && await ref.read(windowServiceProvider).isFocused()) return;
    await go(WindowMode.overlay);
  }

  /// Call after the queue shrinks. Hides the overlay once nothing is left.
  void afterAlertChange() {
    if (state == WindowMode.overlay && ref.read(alertQueueProvider).isEmpty) {
      go(WindowMode.hidden);
    }
  }

  /// Window lost focus.
  void handleBlur() {
    if (DateTime.now().difference(_shownAt) < const Duration(milliseconds: 700)) return;
    if (state == WindowMode.quickAdd) {
      closeTransient();
    } else if (state == WindowMode.manager && ref.read(alertQueueProvider).isNotEmpty) {
      // The user walked away with an alert unanswered: put it on top again.
      go(WindowMode.overlay);
    }
  }
}

final windowModeProvider = NotifierProvider<WindowModeController, WindowMode>(WindowModeController.new);

// ---------------------------------------------------------------------------
// The clock that makes alerts happen
// ---------------------------------------------------------------------------

class SchedulerRunner {
  SchedulerRunner(this._ref);

  final Ref _ref;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void tick() {
    try {
      final now = DateTime.now();
      final result = Scheduler.evaluate(
        now: now,
        data: _ref.read(appControllerProvider),
        active: _ref.read(alertQueueProvider).toSet(),
      );
      if (result.missedTaskIds.isNotEmpty) {
        _ref.read(appControllerProvider.notifier).markMissed(result.missedTaskIds, now);
      }
      if (result.due.isNotEmpty) {
        _ref.read(alertQueueProvider.notifier).enqueue(result.due.map((t) => t.id));
        _ref.read(windowModeProvider.notifier).onAlertsArrived();
      }
    } catch (e, st) {
      debugPrint('VidHub: scheduler tick failed: $e\n$st');
    }
  }
}

final schedulerRunnerProvider = Provider<SchedulerRunner>((ref) {
  final runner = SchedulerRunner(ref);
  ref.onDispose(runner.stop);
  return runner;
});
