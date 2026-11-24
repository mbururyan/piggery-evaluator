import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Drawn by hand rather than with a chart package. Bars are just boxes
// and a donut is a few arcs; a package would bring its own fonts,
// animations and API changes to keep up with, for charts this simple.

/// One bar in [VBarChart].
class BarDatum {
  const BarDatum(this.label, this.value, {this.highlight = false});
  final String label;
  final int value;

  /// Drawn in full red; the rest are a lighter red.
  final bool highlight;
}

/// Upright bars with the count on top and a label underneath.
class VBarChart extends StatelessWidget {
  const VBarChart({super.key, required this.bars, this.height = 110});

  final List<BarDatum> bars;

  /// The tallest bar's height. Labels add about 40 px around it.
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = bars.fold<int>(0, (m, b) => math.max(m, b.value));
    // Many bars (3 months ≈ 13 weeks) get smaller text so labels fit.
    final small = bars.length > 8;

    return SizedBox(
      height: height + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: small ? 1.5 : 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Zero shows no number: a row of 0s is noise.
                    Text(b.value == 0 ? '' : '${b.value}',
                        style: TextStyle(
                            fontSize: small ? 9.5 : 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    const SizedBox(height: 3),
                    Container(
                      // A zero bar is a 2 px line, so the slot reads as
                      // "nothing that week" rather than missing.
                      height: top == 0 ? 2 : math.max(2, height * b.value / top),
                      decoration: BoxDecoration(
                        color: b.value == 0
                            ? AppColors.line
                            : (b.highlight ? AppColors.red : const Color(0xFFE7A3AE)),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(b.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                            fontSize: small ? 9 : 10.5,
                            fontWeight: b.highlight ? FontWeight.w600 : FontWeight.w400,
                            color: b.highlight ? AppColors.ink : AppColors.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of a sideways bar list: label, bar, value.
class HBarRow extends StatelessWidget {
  const HBarRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.value,
    this.color = AppColors.red,
    this.onTap,
  });

  final String label;

  /// 0–1: how full the bar is.
  final double fraction;

  /// What's printed at the end ("148", "62%").
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: LayoutBuilder(
            builder: (context, c) => Stack(children: [
              // Width given outright: a Stack lets its children be any
              // size, and an empty Container would shrink to nothing.
              Container(
                height: 8,
                width: c.maxWidth,
                decoration: BoxDecoration(
                    color: AppColors.line, borderRadius: BorderRadius.circular(4)),
              ),
              Container(
                height: 8,
                width: c.maxWidth * fraction.clamp(0.0, 1.0),
                decoration:
                    BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
            ]),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
        ),
      ]),
    );
    return onTap == null
        ? row
        : InkWell(borderRadius: BorderRadius.circular(6), onTap: onTap, child: row);
  }
}

/// Two bars under one label (pigs over sows), on one shared scale so the
/// sow bar shows how much of the herd is breeding stock.
class PairBarRow extends StatelessWidget {
  const PairBarRow({
    super.key,
    required this.label,
    this.sub,
    required this.first,
    required this.second,
    required this.max,
    this.firstColor = AppColors.red,
    this.secondColor = const Color(0xFFE7A3AE),
  });

  final String label;

  /// Muted text after the label ("12 farms").
  final String? sub;
  final int first;
  final int second;

  /// The biggest value on the card: every row's bars are measured
  /// against it, so rows compare with each other.
  final int max;
  final Color firstColor;
  final Color secondColor;

  @override
  Widget build(BuildContext context) {
    Widget bar(int value, Color color) => Row(children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Stack(children: [
                // Width given outright, as in HBarRow.
                Container(
                  height: 7,
                  width: c.maxWidth,
                  decoration: BoxDecoration(
                      color: AppColors.line, borderRadius: BorderRadius.circular(4)),
                ),
                Container(
                  height: 7,
                  width: max == 0 ? 0 : c.maxWidth * (value / max).clamp(0.0, 1.0),
                  decoration:
                      BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              ]),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
        ]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: label, style: const TextStyle(color: AppColors.ink)),
            if (sub != null)
              TextSpan(text: '  ·  $sub', style: const TextStyle(color: AppColors.muted)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5),
        ),
        const SizedBox(height: 4),
        bar(first, firstColor),
        const SizedBox(height: 3),
        bar(second, secondColor),
      ]),
    );
  }
}

/// One slice of a [Donut].
class DonutSegment {
  const DonutSegment(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

/// A ring chart with something (usually a number) in the middle.
class Donut extends StatelessWidget {
  const Donut({
    super.key,
    required this.segments,
    this.size = 112,
    this.thickness = 15,
    this.center,
  });

  final List<DonutSegment> segments;
  final double size;
  final double thickness;
  final Widget? center;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(segments, thickness),
          child: Center(child: center),
        ),
      );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.thickness);
  final List<DonutSegment> segments;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(thickness / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    final shown = segments.where((s) => s.value > 0).toList();
    final total = shown.fold<int>(0, (n, s) => n + s.value);
    if (total == 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = AppColors.line);
      return;
    }

    // A thin gap between slices so neighbours with similar colours stay
    // apart; none when there's only one slice, or the ring has a notch.
    final gap = shown.length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2; // 12 o'clock
    for (final s in shown) {
      final sweep = 2 * math.pi * s.value / total;
      canvas.drawArc(rect, start + gap / 2, math.max(0, sweep - gap), false,
          paint..color = s.color);
      start += sweep;
    }
  }

  // Cheap to draw, and the segments are rebuilt each time anyway.
  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

/// The key beside a donut: dot, label, count and share.
class DonutLegend extends StatelessWidget {
  const DonutLegend({super.key, required this.segments, this.showPct = true});

  final List<DonutSegment> segments;
  final bool showPct;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (n, s) => n + s.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in segments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.5),
            child: Row(children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink)),
              ),
              Text('${s.value}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
              if (showPct)
                SizedBox(
                  width: 38,
                  child: Text(total == 0 ? '' : '${(100 * s.value / total).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
            ]),
          ),
      ],
    );
  }
}