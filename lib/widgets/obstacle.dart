import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

enum ObstacleShape { square, triangle, star, octagon }

/// Represents an obstacle that can move and rotate.
class Obstacle {
  final int id;
  Offset position; // center point
  final ObstacleShape shape;
  final Color color;
  final double size;

  Obstacle({
    required this.id,
    required this.position,
    required this.shape,
    required this.color,
    this.size = 32.0,
  });

  bool hitTest(Offset point, {double padding = 0}) {
    final half = size / 2 + padding;
    return (point.dx >= position.dx - half &&
        point.dx <= position.dx + half &&
        point.dy >= position.dy - half &&
        point.dy <= position.dy + half);
  }
}

typedef ObstacleHitCallback = void Function(Obstacle obstacle);
typedef VoidCallback = void Function();

/// Controls spawning and collision for obstacles.
class ObstacleController {
  final ObstacleHitCallback onHit;
  final VoidCallback onUpdate;
  final Random _rnd = Random();

  final List<Obstacle> _obstacles = [];
  int _nextId = 0;
  Timer? _timer;

  final int maxObstacles;
  final Duration minInterval;
  final Duration maxInterval;

  ObstacleController({
    required this.onHit,
    required this.onUpdate,
    this.maxObstacles = 10,
    this.minInterval = const Duration(seconds: 1),
    this.maxInterval = const Duration(seconds: 5),
  });

  void start() {
    _scheduleNextSpawn();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  List<Obstacle> get obstacles => List.unmodifiable(_obstacles);

  void checkCollisions(Offset point, {double padding = 0}) {
    for (final o in List.of(_obstacles)) {
      if (o.hitTest(point, padding: padding)) {
        onHit(o);
        _obstacles.remove(o);
        onUpdate();
        break;
      }
    }
  }

  void _scheduleNextSpawn() {
    final minMs = minInterval.inMilliseconds;
    final maxMs = maxInterval.inMilliseconds;
    final intervalMs = minMs + _rnd.nextInt(maxMs - minMs + 1);
    _timer = Timer(Duration(milliseconds: intervalMs), () {
      _spawnRandomCount();
      _scheduleNextSpawn();
    });
  }

  void _spawnRandomCount() {
    final missing = maxObstacles - _obstacles.length;
    if (missing <= 0) return;
    final count = _rnd.nextInt(missing + 1);
    final screen = WidgetsBinding.instance.window.physicalSize /
        WidgetsBinding.instance.window.devicePixelRatio;
    final yMax = screen.height / 3;
    for (var i = 0; i < count; i++) {
      final shape =
          ObstacleShape.values[_rnd.nextInt(ObstacleShape.values.length)];
      final color = [Colors.red, Colors.blue, Colors.yellow][_rnd.nextInt(3)];
      const size = 32.0;
      final x = size / 2 + _rnd.nextDouble() * (screen.width - size);
      final y = size / 2 + _rnd.nextDouble() * (yMax - size);
      _obstacles.add(Obstacle(
        id: _nextId++,
        position: Offset(x, y),
        shape: shape,
        color: color,
        size: size,
      ));
    }
    if (count > 0) onUpdate();
  }
}

/// Animated obstacle: enters from above, then floats & rotates in top third.
class AnimatedObstacleWidget extends StatefulWidget {
  final Obstacle obstacle;
  const AnimatedObstacleWidget({super.key, required this.obstacle});

  @override
  _AnimatedObstacleWidgetState createState() => _AnimatedObstacleWidgetState();
}

class _AnimatedObstacleWidgetState extends State<AnimatedObstacleWidget>
    with TickerProviderStateMixin {
  bool _hasEntered = false;
  late Offset _entryTarget;
  late Offset _currentPos;
  late AnimationController _moveController;
  late Animation<Offset> _moveAnim;
  late AnimationController _rotateController;
  final Random _rnd = Random();
  static const double _maxSpeed = 10.0; // px per second

  @override
  void initState() {
    super.initState();
    // save target and initialize off-screen
    _entryTarget = widget.obstacle.position;
    _currentPos = Offset(_entryTarget.dx, -widget.obstacle.size / 2);
    widget.obstacle.position = _currentPos;

    _moveController = AnimationController(vsync: this)
      ..addStatusListener(_onMoveStatus)
      ..addListener(_onMoveTick);

    // slow back-and-forth rotation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startNewMove();
  }

  void _onMoveStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _startNewMove();
  }

  void _startNewMove() {
    final size = widget.obstacle.size;
    final screen = MediaQuery.of(context).size;
    final xMin = size / 2;
    final xMax = screen.width - size / 2;
    final yMin = size / 2;
    final yMax = screen.height / 3 - size / 2;

    if (!_hasEntered) {
      // entry animation from above to entryTarget
      _moveController.duration = const Duration(seconds: 1);
      _moveAnim = Tween<Offset>(
        begin: _currentPos,
        end: _entryTarget,
      ).animate(CurvedAnimation(
        parent: _moveController,
        curve: Curves.easeOut,
      ));
      _moveController.forward(from: 0).then((_) {
        widget.obstacle.position = _entryTarget;
        _currentPos = _entryTarget;
        _hasEntered = true;
      });
      return;
    }

    // drift animation after entry
    final durationSec = 1 + _rnd.nextDouble() * 2;
    final maxDist = _maxSpeed * durationSec;
    final dx = (_rnd.nextDouble() * 2 - 1) * maxDist;
    final dy = (_rnd.nextDouble() * 2 - 1) * maxDist;
    final target = Offset(
      (_currentPos.dx + dx).clamp(xMin, xMax),
      (_currentPos.dy + dy).clamp(yMin, yMax),
    );
    _moveController.duration =
        Duration(milliseconds: (durationSec * 1000).round());
    _moveAnim = Tween<Offset>(begin: _currentPos, end: target).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );
    _moveController.forward(from: 0);
  }

  void _onMoveTick() {
    setState(() {
      _currentPos = _moveAnim.value;
      widget.obstacle.position = _currentPos;
    });
  }

  @override
  void dispose() {
    _moveController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentPos.dx - widget.obstacle.size / 2,
      top: _currentPos.dy - widget.obstacle.size / 2,
      child: RotationTransition(
        turns: _rotateController,
        child: Icon(
          _shapeToIcon(widget.obstacle.shape),
          color: widget.obstacle.color,
          size: widget.obstacle.size,
        ),
      ),
    );
  }

  IconData _shapeToIcon(ObstacleShape shape) {
    switch (shape) {
      case ObstacleShape.square:
        return Icons.square_rounded;
      case ObstacleShape.triangle:
        return Icons.play_arrow_rounded;
      case ObstacleShape.star:
        return Icons.star_rounded;
      case ObstacleShape.octagon:
        return Icons.hexagon_rounded;
    }
  }
}
