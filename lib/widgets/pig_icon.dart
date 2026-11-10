import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// The pig head from G1 as a one-colour icon: Piggery's version of RE's
/// bull-head Visits icon.
///
/// RE used ImageIcon with a PNG, which picks up its colour from the
/// surrounding IconTheme automatically. An SVG doesn't, so this reads the
/// IconTheme itself. The result is the same: the bottom nav tints it muted
/// when idle and red when selected, with no second copy of the file.
class PigIcon extends StatelessWidget {
  const PigIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = iconTheme.size ?? 24;

    return SvgPicture.asset(
      'assets/brand/pig_head.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        iconTheme.color ?? AppColors.muted,
        BlendMode.srcIn,
      ),
    );
  }
}