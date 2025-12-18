import 'package:flutter/widgets.dart';

class TopRightWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start at top-left, draw a concave wave along the top edge,
    // then include the full rectangle below so content isn't clipped.
    path.moveTo(0, 0);
    path.lineTo(0, size.height * .35);
    path.quadraticBezierTo(
      size.width * .30,
      size.height * .08,
      size.width * .62,
      size.height * .20,
    );
    path.quadraticBezierTo(
      size.width * .90,
      size.height * .30,
      size.width,
      size.height * .14,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}


