import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The number box used across the visit: Production's figures, the
/// population bands, the 12 intake months, ready-for-market.
///
/// Grey when empty, white once filled, red outline while typing, orange
/// only when [error] is set. The whole tile is the tap target, so a thumb
/// anywhere on it opens the keyboard.
class NumberTile extends StatelessWidget {
  const NumberTile({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.unit,
    this.decimals = false,
    this.footer,
    this.error,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? unit;

  /// Allow a decimal point (weights, mortality %). Counts of pigs never.
  final bool decimals;

  /// Small grey line at the foot under a dashed divider (Production's
  /// "target 13"). Null hides both.
  final String? footer;

  /// Shown in orange under the number, and turns the outline orange.
  final String? error;

  final TextInputAction action;
  final VoidCallback? onSubmitted;
  final VoidCallback? onChanged;
  final bool enabled;

  /// Smaller label and number, for three or four tiles across
  /// (population bands, intake months).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final filled = controller.text.trim().isNotEmpty;
    final bad = error != null;
    final numberSize = compact ? 20.0 : 24.0;

    final Color border = bad
        ? AppColors.alert
        : focused
            ? AppColors.red
            : AppColors.line;

    return GestureDetector(
      onTap: enabled ? focusNode.requestFocus : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: compact
            ? const EdgeInsets.fromLTRB(9, 7, 9, 7)
            : const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          // Empty tiles sit back in the page colour; filled ones turn
          // white, so what's left stands out without any labels.
          color: filled || focused ? AppColors.white : AppColors.page,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: focused || bad ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed height so numbers line up across a row even when one
            // label wraps and its neighbour doesn't.
            SizedBox(
              height: compact ? 15 : 32,
              child: Text(label,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      height: 1.3,
                      color: AppColors.muted)),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    onChanged: (_) => onChanged?.call(),
                    onSubmitted: (_) => onSubmitted?.call(),
                    textInputAction: action,
                    keyboardType: TextInputType.numberWithOptions(decimal: decimals),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          decimals ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: TextStyle(
                        fontSize: numberSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                    // Every border set to none: the theme's input borders
                    // would otherwise draw a box inside the tile.
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: '—',
                      hintStyle: TextStyle(
                          fontSize: numberSize,
                          fontWeight: FontWeight.w400,
                          color: AppColors.inputBorder),
                    ),
                  ),
                ),
                if (unit != null)
                  Text(unit!,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
            if (bad)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error!,
                    style: const TextStyle(fontSize: 11, color: AppColors.alert)),
              ),
            if (footer != null) ...[
              SizedBox(height: compact ? 5 : 7),
              const _DashedLine(),
              SizedBox(height: compact ? 3 : 5),
              Text(footer!,
                  style: TextStyle(fontSize: compact ? 10.5 : 11, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lays tiles out [perRow] across with even gaps. A short last row keeps
/// empty slots, so every tile stays the same width.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.perRow, required this.children});

  final int perRow;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = perRow > 2 ? 8.0 : 10.0;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += perRow) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var j = 0; j < perRow; j++) ...[
            if (j > 0) SizedBox(width: gap),
            Expanded(
                child: i + j < children.length ? children[i + j] : const SizedBox()),
          ],
        ],
      ));
    }
    return Column(children: rows);
  }
}

/// Text controllers + focus nodes for a set of number tiles, with the
/// keyboard's Next key walking through them in order. Shared by every
/// screen that uses tiles so the focus plumbing lives in one place.
class TileFields {
  TileFields(this.ids, {required Map<String, dynamic> initial, required VoidCallback onFocusChange}) {
    for (final id in ids) {
      final v = initial[id];
      ctrl[id] = TextEditingController(text: v is num ? fmt(v) : '');
      focus[id] = FocusNode()..addListener(onFocusChange);
    }
  }

  /// In screen order: the order Next walks through.
  final List<String> ids;
  final ctrl = <String, TextEditingController>{};
  final focus = <String, FocusNode>{};

  /// 8.0 shows as "8", 4.5 as "4.5".
  static String fmt(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String text(String id) => ctrl[id]!.text.trim().replaceAll(',', '.');

  /// A whole number typed in [id], or null if blank.
  int? intOf(String id) => int.tryParse(text(id));

  bool get anyTyped => ids.any((id) => text(id).isNotEmpty);

  TextInputAction actionFor(String id) =>
      id == ids.last ? TextInputAction.done : TextInputAction.next;

  /// Next key: on to the next tile; the keyboard closes after the last.
  void next(String id) {
    final i = ids.indexOf(id);
    if (i < ids.length - 1) {
      focus[ids[i + 1]]!.requestFocus();
    } else {
      focus[id]!.unfocus();
    }
  }

  void dispose() {
    for (final c in ctrl.values) {
      c.dispose();
    }
    for (final f in focus.values) {
      f.dispose();
    }
  }
}

/// A 1 px dashed divider. Flutter has no dashed border, so it's painted.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 1, width: double.infinity, child: CustomPaint(painter: _DashPainter()));
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
          Offset(x, 0.5), Offset(x + 4 > size.width ? size.width : x + 4, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}