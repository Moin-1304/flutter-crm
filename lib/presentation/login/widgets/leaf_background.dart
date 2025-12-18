import 'dart:ui';

import 'package:boilerplate/constants/assets.dart';
import 'package:flutter/material.dart';

class LeafBackground extends StatelessWidget {
  final Widget child;
  final double blur;
  final bool dark;

  const LeafBackground({
    super.key,
    required this.child,
    required this.dark,
    this.blur = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          Assets.leavesBackground,
          fit: BoxFit.cover,
        ),
        // global scrim to ensure foreground legibility regardless of image
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: dark ? 0.30 : 0.45),
                Colors.black.withValues(alpha: dark ? 0.40 : 0.55),
              ],
            ),
          ),
        ),
        if (blur > 0)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(color: Colors.transparent),
          ),
        child,
      ],
    );
  }
}


