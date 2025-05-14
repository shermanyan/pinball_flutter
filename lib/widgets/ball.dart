import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/paddle.dart';
import '../widgets/obstacle.dart';

/// Controls the ball’s motion, collision, and lifecycle.
class BallController {
  Offset _position;
  Offset _velocity;
  final double radius;

  final Offset _initialPosition;
  final double _speed;

  bool _isRunning = false;

  BallController({
    required Offset startPosition,
    required double speed,
    this.radius = 10.0,
  })  : _position = startPosition,
        _speed = speed,
        _velocity = _genVelocity(speed),
        _initialPosition = startPosition;

  static Offset _genVelocity(double speed) {
    final angle =
        (Random().nextDouble() * 2 * pi).clamp(2 * pi / 3, 5 * pi / 6);
    return Offset.fromDirection(angle, speed);
  }

  Offset getPos() => _position;
  Offset get velocity => _velocity;
  double get ballRadius => radius;

  void moveTo(Offset pos) => _position = pos;

  bool checkCollision(Offset point, double r) {
    return (point - _position).distance <= radius + r;
  }

  void start() => _isRunning = true;

  bool get isRunning => _isRunning;

  void reset() {
    _isRunning = false;
    _position = _initialPosition;
    _velocity = _genVelocity(_speed);
  }

  void update(double dt, Size size) {
    if (!_isRunning) return;
    final nextPos = _position + _velocity * dt;

    // Bounce off walls
    if (nextPos.dx - radius <= 0 || nextPos.dx + radius >= size.width) {
      _velocity = Offset(-_velocity.dx, _velocity.dy);
    }
    if (nextPos.dy - radius <= 0) {
      _velocity = Offset(_velocity.dx, -_velocity.dy);
    }

    _position += _velocity * dt;
  }

  void bounce() {
    _velocity = Offset(_velocity.dx, -_velocity.dy);
  }

  bool isOutOfBounds(Size size) => _position.dy - radius >= size.height;
}

class BallWidget extends StatefulWidget {
  final BallController controller;
  final RotatingPaddleController leftPaddleController;
  final RotatingPaddleController rightPaddleController;
  final ObstacleController obstacleController;

  final VoidCallback onGameOver;

  const BallWidget(
      {super.key,
      required this.controller,
      required this.leftPaddleController,
      required this.rightPaddleController,
      required this.obstacleController,
      required this.onGameOver});

  @override
  State<BallWidget> createState() => _BallWidgetState();
}

class _BallWidgetState extends State<BallWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    final screenSize = MediaQuery.of(context).size;

    if (!widget.controller.isRunning) return;

    // move the ball
    setState(() {
      widget.controller.update(1 / 60, screenSize);
    });

    // grab its new position
    final pos = widget.controller.getPos();
    final r = widget.controller.ballRadius;

    // paddle collisions
    final leftHit = widget.leftPaddleController.paddle.hitTest(pos, padding: r);
    final rightHit =
        widget.rightPaddleController.paddle.hitTest(pos, padding: r);
    if (leftHit || rightHit) {
      widget.controller.bounce();
      return;
    }

    // obstacle collisions
    if (widget.obstacleController.checkCollisions(pos, padding: r)) {
      widget.controller.bounce();
      return;
    }

    // out-of-bounds
    if (widget.controller.isOutOfBounds(screenSize)) {
      widget.onGameOver();
      widget.controller.reset();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.controller.getPos();
    final r = widget.controller.radius;
    return Positioned(
      left: pos.dx - r,
      top: pos.dy - r,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.green)],
        ),
      ),
    );
  }
}
