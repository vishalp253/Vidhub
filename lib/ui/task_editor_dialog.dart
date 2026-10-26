import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ids.dart';
import '../core/time_utils.dart';
import '../models/launch_item.dart';
import '../models/task.dart';
import '../providers/app_providers.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opens the editor. Returns the saved task, or null if cancelled.
Future<Task?> showTaskEditor(BuildContext context, {Task? initial}) {
  return showDialog<Task>(
    context: context,
    builder: (_) => TaskEditorDialog(initial: initial),
  );
}

class TaskEditorDialog extends ConsumerStatefulWidget {
  const TaskEditorDialog({super.key, this.initial});

  final Task? initial;

  @override
  ConsumerState<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends ConsumerState<TaskEditorDialog> {
  late final TextEditingController _title;
  final TextEditingController _itemText = TextEditingController();

  late TimeOfDay _time;
  late bool _repeat;
  late Set<int> _days;
  late DateTime _date;
  late List<LaunchItem> _items;

  String? _error;
  String? _testMessage;
  bool _testFailed = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    final now = DateTime.now();
    if (t == null) {
      _title = TextEditingController();
      final next = now.add(const Duration(hours: 1));
      _time = TimeOfDay(hour: next.hour, minute: 0);
      _repeat = true;
      _days = {...kEveryDay};
      _date = dateOnly(now);
      _items = [];
    } else {
      _title = TextEditingController(text: t.title);
      _time = TimeOfDay(hour: t.minuteOfDay ~/ 60, minute: t.minuteOfDay % 60);
      _repeat = !t.isOneOff;
      _days = {...t.weekdays};
      _date = t.isOneOff ? parseDateKey(t.oneOffDate!) : dateOnly(now);
      _items = [...t.items];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _itemText.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  void _addItem() {
    final raw = _itemText.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _items.add(LaunchItem.guess(raw));
      _itemText.clear();
      _testMessage = null;
    });
  }

  Future<void> _testItem(LaunchItem item) async {
    final result = await ref.read(launcherProvider).launch(item);
    if (!mounted) return;
    setState(() {
      _testFailed = !result.ok;
      _testMessage = result.ok ? 'Opened ${item.displayName}' : result.error;
    });
  }

  void _save() {
    _addItem(); // don't lose a link that was typed but not added
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a name.');
      return;
    }
    if (_repeat && _days.isEmpty) {
      setState(() => _error = 'Pick at least one day, or switch to "Once".');
      return;
    }
    final minute = _time.hour * 60 + _time.minute;
    final initial = widget.initial;
    final task = initial == null
        ? Task(
            id: newId(),
            title: title,
            minuteOfDay: minute,
            weekdays: _repeat ? _days : kEveryDay,
            oneOffDate: _repeat ? null : dateKey(_date),
            items: _items,
          )
        : initial.copyWith(
            title: title,
            minuteOfDay: minute,
            weekdays: _repeat ? _days : kEveryDay,
            oneOffDate: _repeat ? null : dateKey(_date),
            items: _items,
          );
    Navigator.of(context).pop(task);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text.toUpperCase(), style: TP.label()),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Dialog(
      backgroundColor: TP.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: TP.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? 'Edit task' : 'New task',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: TP.text),
              ),
              _label('What'),
              TextField(
                controller: _title,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: TP.text),
                decoration: tpInput(hint: 'Duolingo'),
                onSubmitted: (_) => _save(),
              ),
              _label('When'),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      formatMinuteOfDay(_time.hour * 60 + _time.minute),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TP.text,
                      side: const BorderSide(color: TP.line),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Repeats')),
                      ButtonSegment(value: false, label: Text('Once')),
                    ],
                    selected: {_repeat},
                    onSelectionChanged: (s) => setState(() => _repeat = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_repeat) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(kWeekdayShort[d - 1]),
                        selected: _days.contains(d),
                        showCheckmark: false,
                        selectedColor: TP.accent.withAlpha(60),
                        backgroundColor: TP.raised,
                        side: BorderSide(color: _days.contains(d) ? TP.accent : TP.line),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _days.add(d);
                          } else {
                            _days.remove(d);
                          }
                          _error = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _days = {...kEveryDay}),
                      child: const Text('Every day'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _days = {...kWeekdaysMonFri}),
                      child: const Text('Weekdays'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _days = {...kWeekend}),
                      child: const Text('Weekends'),
                    ),
                  ],
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text('${friendlyDate(_date, DateTime.now())}  ·  ${longDate(_date)}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TP.text,
                      side: const BorderSide(color: TP.line),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              _label('Open when it fires (optional)'),
              for (var i = 0; i < _items.length; i++) _itemRow(i),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemText,
                      style: const TextStyle(fontSize: 14, color: TP.text),
                      decoration: tpInput(hint: r'duolingo.com   ·   vscode://   ·   C:\Tools\app.exe   ·   code'),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: _addItem,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Websites, app links, programs, files and folders all work. Everything opens in one click from the alert.',
                style: TextStyle(fontSize: 12, color: TP.muted, height: 1.4),
              ),
              if (_testMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _testMessage!,
                  style: TextStyle(fontSize: 12.5, color: _testFailed ? TP.bad : TP.good),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 13, color: TP.bad)),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: TP.muted)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: TP.accent,
                      foregroundColor: TP.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: Text(editing ? 'Save' : 'Add task'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: TP.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TP.line),
      ),
      child: Row(
        children: [
          Icon(iconForKind(item.kind), size: 18, color: TP.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName, style: const TextStyle(fontSize: 14, color: TP.text, fontWeight: FontWeight.w600)),
                Text(
                  item.target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: TP.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Test it now',
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            color: TP.muted,
            onPressed: () => _testItem(item),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: TP.muted,
            onPressed: () => setState(() => _items.removeAt(index)),
          ),
        ],
      ),
    );
  }
}
