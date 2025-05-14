// -------------------------
// lib/widgets/paddle.dart
// -------------------------
import 'dart:math';
import 'package:flutter/material.dart';

enum PaddleSide { left, right }

class Paddle {
  final PaddleSide id;
  Offset position;
  double length;
  double width;
  double angle;

  Paddle({
    required this.id,
    this.position = Offset.zero,
    required this.length,
    required this.width,
    double? angle,
  }) : angle = angle ?? 0.0;

  bool hitTest(Offset point, {double padding = 0}) {
    final dx = point.dx - position.dx;
    final dy = point.dy - position.dy;
    final c = cos(-angle), s = sin(-angle);
    final localX = dx * c - dy * s;
    final localY = dx * s + dy * c;
    final halfLen = length / 2 + padding;
    final halfWid = width / 2 + padding;
    return localX >= -halfLen &&
        localX <= halfLen &&
        localY >= -halfWid &&
        localY <= halfWid;
  }
}

class RotatingPaddleController {
  final Paddle paddle;
  final AnimationController _animCtrl;
  late final Animation<double> angleAnim;
  static const double _maxAngle = pi / 4;
  static const double _minAngle = -pi / 12;

  RotatingPaddleController({
    required TickerProvider vsync,
    required Offset position,
    required PaddleSide id,
    double length = 105,
    double width = 25,
    Duration duration = const Duration(milliseconds: 100),
  })  : _animCtrl = AnimationController(vsync: vsync, duration: duration),
        paddle = Paddle(
          id: id,
          position: position,
          length: length,
          width: width,
          angle: id == PaddleSide.left ? -_minAngle : _minAngle,
        ) {
    final begin = paddle.angle;
    final target = id == PaddleSide.left ? -_maxAngle : _maxAngle;
    angleAnim = Tween<double>(begin: begin, end: target)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut))
      ..addListener(() {
        paddle.angle = angleAnim.value;
      });
  }

  void flipUp() => _animCtrl.forward();
  void flipDown() => _animCtrl.reverse();
  void dispose() => _animCtrl.dispose();
}

class RotatingPaddleWidget extends StatelessWidget {
  final RotatingPaddleController controller;

  const RotatingPaddleWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = controller.paddle;
    final halfH = p.width / 2;
    Alignment alignment;
    double left;
    if (p.id == PaddleSide.left) {
      alignment = Alignment.centerLeft;
      left = p.position.dx;
    } else {
      alignment = Alignment.centerRight;
      left = p.position.dx - p.length;
    }
    final top = p.position.dy - halfH;

    return AnimatedBuilder(
        animation: controller.angleAnim,
        builder: (_, __) {
          return Positioned(
            left: left,
            top: top,
            child: Transform.rotate(
              angle: p.angle,
              alignment: alignment,
              child: Container(
                width: p.length,
                height: p.width,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(p.width / 2),
                  boxShadow: [BoxShadow(color: Colors.white, blurRadius: 2)],
                ),
              ),
            ),
          );
        });
  }
}
