import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/quick_add_parser.dart';
import '../providers/app_providers.dart';
import 'theme.dart';

/// The tiny box that opens on Ctrl+Shift+T. Type a time and a title, press Enter.
class QuickAddView extends ConsumerStatefulWidget {
  const QuickAddView({super.key});

  @override
  ConsumerState<QuickAddView> createState() => _QuickAddViewState();
}

class _QuickAddViewState extends ConsumerState<QuickAddView> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  QuickAddResult? _parsed;
  String? _addedSummary;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (_addedSummary != null) return;
      setState(() => _parsed = parseQuickAdd(_text.text));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    ref.read(windowModeProvider.notifier).closeTransient();
  }

  Future<void> _submit() async {
    if (_addedSummary != null) return;
    final parsed = parseQuickAdd(_text.text);
    if (parsed == null) return;
    final summary = parsed.summary(DateTime.now());
    ref.read(appControllerProvider.notifier).addFromQuickAdd(parsed);
    setState(() => _addedSummary = summary);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _text.text.trim().isNotEmpty;

    final Widget hint;
    if (_addedSummary != null) {
      hint = Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: TP.good),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Added  ·  $_addedSummary',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: TP.good, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    } else if (_parsed != null) {
      hint = Row(
        children: [
          const Icon(Icons.keyboard_return_rounded, size: 16, color: TP.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _parsed!.summary(DateTime.now()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: TP.text, fontWeight: FontWeight.w600),
            ),
          ),
          const Text('Enter to add   ·   Esc to cancel', style: TextStyle(fontSize: 12, color: TP.muted)),
        ],
      );
    } else if (hasText) {
      hint = const Text(
        'Start with a time:  5pm gym   ·   +30m stretch   ·   11:00 AM | Duolingo',
        style: TextStyle(fontSize: 12.5, color: TP.warn),
      );
    } else {
      hint = const Text(
        '5pm gym   ·   +30m stretch   ·   daily 7am | Wake up   ·   11:00 AM | Duolingo | duolingo.com',
        style: TextStyle(fontSize: 12.5, color: TP.muted, height: 1.4),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TP.surface,
          border: Border.all(color: TP.accent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: TP.accent, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      autofocus: true,
                      enabled: _addedSummary == null,
                      onSubmitted: (_) => _submit(),
                      cursorColor: TP.accent,
                      style: const TextStyle(fontSize: 21, color: TP.text, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: '11:00 AM | Duolingo',
                        hintStyle: TextStyle(color: TP.muted, fontSize: 21),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: TP.line),
              const SizedBox(height: 10),
              hint,
            ],
          ),
        ),
      ),
    );
  }
}
