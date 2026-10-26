import 'package:flutter/material.dart';

import '../logic/today_status.dart';
import '../models/launch_item.dart';
import 'theme.dart';

/// A dot with a soft ring that keeps expanding: "something is due".
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = TP.accent, this.size = 10});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.6,
      height: s * 2.6,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final ring = s + s * 1.6 * t;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withAlpha(((1 - t) * 90).round()),
                ),
              ),
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData iconForKind(LaunchKind kind) {
  switch (kind) {
    case LaunchKind.url:
      return Icons.link_rounded;
    case LaunchKind.app:
      return Icons.apps_rounded;
    case LaunchKind.file:
      return Icons.folder_open_rounded;
  }
}

/// Small pill showing one thing a task opens.
class ItemChip extends StatelessWidget {
  const ItemChip({super.key, required this.item});

  final LaunchItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: TP.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TP.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconForKind(item.kind), size: 13, color: TP.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: TP.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TP.line),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: TP.muted)),
    );
  }
}

/// Wraps up to [max] chips and a "+n" for the rest.
class ItemChips extends StatelessWidget {
  const ItemChips({super.key, required this.items, this.max = 3});

  final List<LaunchItem> items;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items.take(max)) ItemChip(item: item),
        if (items.length > max) CountChip(text: '+${items.length - max}'),
      ],
    );
  }
}

/// Coloured label for a task's state today.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (state) {
      TodayState.done => ('Done', TP.good),
      TodayState.skipped => ('Skipped', TP.muted),
      TodayState.missed => ('Missed', TP.bad),
      TodayState.due => ('Due now', TP.accent),
      TodayState.snoozed => ('Snoozed', TP.warn),
      TodayState.upcoming => ('Upcoming', TP.muted),
      TodayState.earlier => ('Earlier', TP.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Page heading used by the manager pages.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1, color: TP.text),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: const TextStyle(fontSize: 14.5, color: TP.muted, height: 1.35)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

/// Rounded surface used for list rows and cards.
class TpCard extends StatelessWidget {
  const TpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.borderColor = TP.line,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: TP.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
