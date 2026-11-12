import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// The Piggery Evaluator logo: red pig head on a white rounded tile.
/// Replaces AppLogo (G1 is retired from this app and kept for later).
///
/// The hairline border and faint shadow are deliberate. On a white screen
/// (splash, login) a white tile would otherwise vanish, leaving a pig cut
/// off at the neck with nothing framing it, which reads as a cropping
/// mistake. The edge keeps the tile visible on any background.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    // 22% matches the rx="22" corner in logo.svg (on a 100-unit tile), so
    // the border follows the tile's own corners exactly.
    final radius = BorderRadius.circular(size * 0.22);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SvgPicture.asset(
          'assets/brand/logo.svg',
          width: size,
          height: size,
          semanticsLabel: 'Piggery Evaluator logo',
        ),
      ),
    );
  }
}