import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/ball.dart';
import '../widgets/paddle.dart';
import '../game_state.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  // ── paddle configuration ──
  static const double _paddleWidth = 80.0;
  static const double _paddleHeight = 20.0;
  static const double _paddleBottom = 20.0;
  double _paddleX = 0;

  bool _moveLeft = false;
  bool _moveRight = false;
  static const double _paddleSpeed = 300.0;

  // ── ball + animation ──
  late final AnimationController _controller;
  late DateTime _lastTime;
  late Ball _ball;
  final double _radius = 10.0;

  @override
  void initState() {
    super.initState();
    _resetBall();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onFrame);
    _lastTime = DateTime.now();

    _resetPaddle();
  }

  void _resetBall() {
    _ball = Ball(
      position: const Offset(180, 320),
      velocity: Offset(
        (150 + (50 * (1 - 2 * (Random().nextDouble())))),
        (200 + (50 * (1 - 2 * (Random().nextDouble())))),
      ),
      radius: _radius,
    );
  }

  void _resetPaddle() {
    _paddleX = (360 - _paddleWidth) / 2;
  }

  void _onFrame() {
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMilliseconds / 1000;
    _lastTime = now;

    final size = MediaQuery.of(context).size;

    // 1) paddle auto‐move
    if (_moveLeft) {
      _paddleX =
          (_paddleX - _paddleSpeed * dt).clamp(0.0, size.width - _paddleWidth);
    }
    if (_moveRight) {
      _paddleX =
          (_paddleX + _paddleSpeed * dt).clamp(0.0, size.width - _paddleWidth);
    }

    // 2) then do your existing ball‐bounce logic...
    Offset pos = _ball.position + _ball.velocity * dt;
    Offset vel = _ball.velocity;

    // bounce off walls & top
    if ((pos.dx - _ball.radius <= 0 && vel.dx < 0) ||
        (pos.dx + _ball.radius >= size.width && vel.dx > 0)) {
      vel = Offset(-vel.dx, vel.dy);
    }
    if (pos.dy - _ball.radius <= 0 && vel.dy < 0) {
      vel = Offset(vel.dx, -vel.dy);
    }

    // paddle collision
    final paddleTopY = size.height - _paddleBottom - _paddleHeight;
    if (vel.dy > 0 &&
        pos.dy + _ball.radius >= paddleTopY &&
        _ball.position.dy + _ball.radius < paddleTopY &&
        pos.dx >= _paddleX &&
        pos.dx <= _paddleX + _paddleWidth) {
      vel = Offset(vel.dx, -vel.dy);
      pos = Offset(pos.dx, paddleTopY - _ball.radius);
    }

    // bottom = game over
    if (pos.dy - _ball.radius >= size.height) vel = Offset.zero;

    final nextBall = Ball(position: pos, velocity: vel, radius: _ball.radius);
    if (nextBall.velocity == Offset.zero) {
      _controller.stop();

      _resetBall();
      _resetPaddle();
      context.read<GameCubit>().endGame(0);
    }
    setState(() => _ball = nextBall);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startGame() {
    _resetBall();
    _lastTime = DateTime.now();
    _controller.repeat();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveLeft = true;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _moveRight = true;
        return KeyEventResult.handled;
      }
    }
    if (event is KeyUpEvent) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveLeft = false;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _moveRight = false;
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listener: (context, state) {
        if (state.status == GameStatus.playing) {
          _startGame();
        } else {
          _controller.stop();
        }
      },
      child: BlocBuilder<GameCubit, GameState>(
        builder: (context, state) => Focus(
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
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => BallWidget(ball: _ball),
                ),
                if (state.status == GameStatus.newGame) const NewGameOverlay(),
                if (state.status == GameStatus.gameOver)
                  GameOverOverlay(score: state.score),
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
    final theme = Theme.of(c);
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            'Pinball',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Orbitron',
              shadows: [
                Shadow(
                  blurRadius: 30,
                  color: theme.colorScheme.primary,
                )
              ],
              decoration: TextDecoration.none,
              color: Colors.white,
            ),
          ),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        '$score',
        style: TextStyle(
          color: Colors.white,
          decoration: TextDecoration.none,
          fontSize: 10,
        ),
      ),
      const PlayButton(),
      const SizedBox(height: 20),
    ]));
  }
}

class PlayButton extends StatelessWidget {
  const PlayButton({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(80, 80),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        shadowColor: theme.colorScheme.primary,
        elevation: 10,
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
