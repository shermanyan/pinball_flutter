import 'package:flutter/material.dart';

class Paddle extends StatelessWidget {
  /// X position of the left edge
  final double x;

  /// Size of the paddle
  final double width;
  final double height;

  /// Distance from bottom of the screen
  final double bottomOffset;

  const Paddle({
    Key? key,
    required this.x,
    this.width = 80.0,
    this.height = 20.0,
    this.bottomOffset = 20.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding =
        20.0; // Add padding to prevent paddle from touching screen edges
    final minX = padding;
    final maxX = screenWidth - width - padding;
    // clamp so paddle never goes off-screen
    final clampedX = x.clamp(minX, maxX);
    final top = MediaQuery.of(context).size.height - bottomOffset - height;

    final theme = Theme.of(context);

    return Positioned(
      left: clampedX,
      top: top,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.secondary, width: 2),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary,
              blurRadius: 10,
            ),
          ],
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
