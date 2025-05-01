// lib/screens/game_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/ball.dart';
import '../widgets/paddle.dart';
import '../widgets/obstacle.dart';
import '../game_state.dart';

import 'dart:math';

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  // paddle config
  static const double _paddleWidth = 80.0;
  static const double _paddleHeight = 20.0;
  static const double _paddleBottom = 20.0;
  double _paddleX = 0.0;

  // ball & animation
  late final AnimationController _controller;
  late DateTime _lastTime;
  late Ball _ball;
  static const double _ballRadius = 10.0;

  // keyboard press flags
  bool _moveLeft = false;
  bool _moveRight = false;
  static const double _paddleSpeed = 300.0;

  // obstacles
  late final ObstacleController _obController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_onFrame);
    _lastTime = DateTime.now();

    _resetBall();

    _obController = ObstacleController(
      onHit: (obs) {
        context.read<GameCubit>().incrementScore();
      },
      onUpdate: () => setState(() {}),
      maxObstacles: 8,
      minInterval: const Duration(seconds: 1),
      maxInterval: const Duration(seconds: 3),
    );
    _obController.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      setState(() {
        _paddleX = (width - _paddleWidth) / 2;
      });
    });
  }

  void _resetBall() {
    _ball = Ball(
      position: const Offset(180, 320),
      velocity: Offset.fromDirection(
        (Random().nextDouble() * 2 * pi).clamp(2 * pi / 3, 5 * pi / 6),
        -300, // Constant speed
      ),
      radius: _ballRadius,
    );
  }

  void _onFrame() {
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMilliseconds / 1000;
    _lastTime = now;
    final size = MediaQuery.of(context).size;

    // handle held keys
    if (_moveLeft) {
      _paddleX =
          (_paddleX - _paddleSpeed * dt).clamp(0.0, size.width - _paddleWidth);
    }
    if (_moveRight) {
      _paddleX =
          (_paddleX + _paddleSpeed * dt).clamp(0.0, size.width - _paddleWidth);
    }

    // ball physics
    Offset pos = _ball.position + _ball.velocity * dt;
    Offset vel = _ball.velocity;

    // bounce walls
    if ((pos.dx - _ball.radius <= 0 && vel.dx < 0) ||
        (pos.dx + _ball.radius >= size.width && vel.dx > 0)) {
      vel = Offset(-vel.dx, vel.dy);
    }
    // bounce ceiling
    if (pos.dy - _ball.radius <= 0 && vel.dy < 0) {
      vel = Offset(vel.dx, -vel.dy);
    }

    // bounce paddle
    final paddleTop = size.height - _paddleBottom - _paddleHeight;
    if (vel.dy > 0 &&
        pos.dy + _ball.radius >= paddleTop &&
        _ball.position.dy + _ball.radius < paddleTop &&
        pos.dx >= _paddleX &&
        pos.dx <= _paddleX + _paddleWidth) {
      vel = Offset(vel.dx, -vel.dy);
      pos = Offset(pos.dx, paddleTop - _ball.radius);
    }

    // obstacle collisions: remove & bounce
    final beforeCount = _obController.obstacles.length;
    _obController.checkCollisions(pos, padding: _ball.radius);
    // if an obstacle was hit, invert vertical velocity
    if (_obController.obstacles.length < beforeCount) {
      final random = Random();
      final speed = vel.distance;
      final angle = (pi / 4) +
          random.nextDouble() * (pi / 2); // Random angle between 45° and 135°
      vel = Offset.fromDirection(angle, speed);
      // reposition to avoid sticking
      pos = _ball.position;
    }

    // bottom => game over
    if (pos.dy - _ball.radius >= size.height) vel = Offset.zero;

    final next = Ball(position: pos, velocity: vel, radius: _ball.radius);
    if (next.velocity == Offset.zero) {
      _controller.stop();
      context.read<GameCubit>().endGame(
            context.read<GameCubit>().state.score,
          );
    }

    setState(() => _ball = next);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _moveLeft = true;
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _moveRight = true;
        return KeyEventResult.handled;
      }
    }
    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _moveLeft = false;
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _moveRight = false;
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _obController.stop();
    super.dispose();
  }

  void _startGame() {
    _resetBall();
    _lastTime = DateTime.now();
    _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (ctx, state) {
        if (state.status == GameStatus.playing) {
          _startGame();
        } else {
          _controller.stop();
        }
      },
      child: BlocBuilder<GameCubit, GameState>(
        builder: (ctx, state) => Focus(
          autofocus: true,
          onKeyEvent: (node, event) => _onKeyEvent(node, event),
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _paddleX = (_paddleX + details.delta.dx).clamp(
                    0.0, MediaQuery.of(context).size.width - _paddleWidth);
              });
            },
            child: Stack(
              children: [
                // ball
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => BallWidget(ball: _ball),
                ),
                // obstacles
                for (final o in _obController.obstacles)
                  AnimatedObstacleWidget(key: ValueKey(o.id), obstacle: o),
                // overlays
                if (state.status == GameStatus.newGame) const NewGameOverlay(),
                if (state.status == GameStatus.gameOver)
                  GameOverOverlay(score: state.score),
                // paddle
                Paddle(
                  x: _paddleX,
                  width: _paddleWidth,
                  height: _paddleHeight,
                  bottomOffset: _paddleBottom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NewGameOverlay extends StatelessWidget {
  const NewGameOverlay({super.key});

  @override
  Widget build(BuildContext c) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const TitleText(),
          const SizedBox(height: 120),
          const PlayButton(),
        ],
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final int score;
  const GameOverOverlay({super.key, required this.score});

  @override
  Widget build(BuildContext c) {
    return Center(
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const SizedBox(height: 40),
      const TitleText(),
      const SizedBox(height: 50),
      Text(
        '$score',
        style: TextStyle(
          fontFamily: 'Orbitron',
          color: Colors.white,
          decoration: TextDecoration.none,
          shadows: [
            Shadow(
              blurRadius: 30,
              color: Theme.of(c).colorScheme.primary,
            )
          ],
          fontSize: 40,
        ),
      ),
      const SizedBox(height: 80),
      const PlayButton(),
    ]));
  }
}

class PlayButton extends StatelessWidget {
  const PlayButton({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(80, 80),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        shadowColor: theme.colorScheme.primary,
        elevation: 5,
        padding: EdgeInsets.zero,
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      onPressed: () => context.read<GameCubit>().startGame(),
      child: Icon(
        Icons.play_arrow_rounded,
        color: theme.colorScheme.secondary,
        size: 40,
        shadows: [
          Shadow(
            blurRadius: 20,
            color: theme.colorScheme.primary,
          )
        ],
      ),
    );
  }
}

class TitleText extends StatelessWidget {
  const TitleText({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Pinball',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Orbitron',
        shadows: [
          Shadow(
            blurRadius: 30,
            color: Theme.of(context).colorScheme.primary,
          )
        ],
        decoration: TextDecoration.none,
        color: Colors.white,
      ),
    );
  }
}
