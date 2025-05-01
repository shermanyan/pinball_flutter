// lib/widgets/ball.dart
import 'package:flutter/material.dart';

class Ball {
  Offset position;
  Offset velocity;
  final double radius;

  Ball({
    required this.position,
    required this.velocity,
    required this.radius,
  });

  Ball copyWith({Offset? position, Offset? velocity}) {
    return Ball(
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      radius: radius,
    );
  }
}

class BallWidget extends StatelessWidget {
  final Ball ball;
  const BallWidget({Key? key, required this.ball}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: ball.position.dx - ball.radius,
      top: ball.position.dy - ball.radius,
      child: Container(
        width: ball.radius * 2,
        height: ball.radius * 2,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
            ),
          ],
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
