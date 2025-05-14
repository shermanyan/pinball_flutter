// lib/widgets/paddle.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Computes the centered X for the paddle
double defaultPaddleX(double screenWidth, double paddleWidth) {
  return (screenWidth - paddleWidth) / 2;
}

/// Callback when the paddle moves
typedef PaddlePositionCallback = void Function(double x);

/// Manages paddle movement logic (drag + keyboard hold)
class PaddleController {
  double x;
  final double speed;
  final double minX;
  final double maxX;
  final PaddlePositionCallback onMove;

  PaddleController({
    required this.x,
    required this.speed,
    required this.minX,
    required this.maxX,
    required this.onMove,
  });

  void drag(double delta) {
    x = (x + delta).clamp(minX, maxX);
    onMove(x);
  }

  void moveLeft(double dt) {
    x = (x - speed * dt).clamp(minX, maxX);
    onMove(x);
  }

  void moveRight(double dt) {
    x = (x + speed * dt).clamp(minX, maxX);
    onMove(x);
  }
}

/// A paddle widget that handles its own input and rendering.
class PaddleWidget extends StatefulWidget {
  final double width;
  final double height;
  final double bottomOffset;

  const PaddleWidget({
    Key? key,
    this.width = 80.0,
    this.height = 20.0,
    this.bottomOffset = 20.0,
  }) : super(key: key);

  @override
  _PaddleWidgetState createState() => _PaddleWidgetState();
}

class _PaddleWidgetState extends State<PaddleWidget> {
  late final PaddleController _controller;
  late final FocusNode _focusNode;
  late final Timer _timer;
  bool _moveLeft = false;
  bool _moveRight = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // auto-focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    // key-hold ticker (~60fps)
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      const dt = 16 / 1000;
      if (_moveLeft) _controller.moveLeft(dt);
      if (_moveRight) _controller.moveRight(dt);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenW = MediaQuery.of(context).size.width;
    final startX = defaultPaddleX(screenW, widget.width);
    _controller = PaddleController(
      x: startX,
      speed: 300.0,
      minX: 0.0,
      maxX: screenW - widget.width,
      onMove: (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _moveLeft = true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _moveRight = true;
      }
    } else if (event is RawKeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _moveLeft = false;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _moveRight = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => _controller.drag(details.delta.dx),
        child: Stack(
          children: [
            Positioned(
              left: _controller.x,
              top: MediaQuery.of(context).size.height -
                  widget.bottomOffset -
                  widget.height,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
