import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The G1 logo: red pig head inside viewfinder brackets, on a white tile.
///
/// On white screens (splash, login) the tile blends into the page, so only
/// the head and brackets show. That's intended. Don't put it on AppColors.page:
/// the off-white page would show the tile's edge as a faint square.
class G1Mark extends StatelessWidget {
  const G1Mark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/g1.svg',
      width: size,
      height: size,
      semanticsLabel: 'Piggery Evaluator logo',
    );
  }
}