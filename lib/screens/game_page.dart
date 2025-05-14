// lib/screens/game_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/ball.dart';
import '../widgets/paddle.dart';
import '../widgets/obstacle.dart';
import '../game_state.dart';

class GamePage extends StatefulWidget {
  const GamePage({Key? key}) : super(key: key);
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  // Ball & animation
  late final AnimationController _controller;
  late DateTime _lastTime;
  late Ball _ball;
  static const double _ballRadius = 10.0;

  // Paddle position
  late final PaddleController _paddleController;
  double _paddleX = 0.0;

  // Obstacles
  late final ObstacleController _obController;

  @override
  void initState() {
    super.initState();
    // Ball
    _controller =
        AnimationController(vsync: this, duration: const Duration(hours: 1))
          ..addListener(_onFrame);
    _lastTime = DateTime.now();
    _resetBall();

    // Paddle setup after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenW = MediaQuery.of(context).size.width;
      final initialX = defaultPaddleX(screenW, 80.0);
      _paddleX = initialX;
      _paddleController = PaddleController(
        x: initialX,
        speed: 300,
        minX: 0,
        maxX: screenW - 80.0,
        onMove: (newX) => setState(() => _paddleX = newX),
      );
    });

    // Obstacles
    _obController = ObstacleController(
      onHit: (obs) => context.read<GameCubit>().incrementScore(),
      onUpdate: () => setState(() {}),
      maxObstacles: 8,
      minInterval: const Duration(seconds: 1),
      maxInterval: const Duration(seconds: 3),
    );
    _obController.start();
  }

  void _resetBall() {
    _ball = Ball(
      position: const Offset(180, 320),
      velocity: Offset.fromDirection(
        (Random().nextDouble() * 2 * pi).clamp(2 * pi / 3, 5 * pi / 6),
        -300,
      ),
      radius: _ballRadius,
    );
  }

  void _onFrame() {
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMilliseconds / 1000;
    _lastTime = now;
    final size = MediaQuery.of(context).size;

    // Ball
    Offset pos = _ball.position + _ball.velocity * dt;
    Offset vel = _ball.velocity;

    // Walls
    if ((pos.dx - _ball.radius <= 0 && vel.dx < 0) ||
        (pos.dx + _ball.radius >= size.width && vel.dx > 0)) {
      vel = Offset(-vel.dx, vel.dy);
    }
    if (pos.dy - _ball.radius <= 0 && vel.dy < 0) {
      vel = Offset(vel.dx, -vel.dy);
    }

    // Paddle
    final paddleTop = size.height - 20.0 - 20.0;
    if (vel.dy > 0 &&
        pos.dy + _ball.radius >= paddleTop &&
        _ball.position.dy + _ball.radius < paddleTop &&
        pos.dx >= _paddleX &&
        pos.dx <= _paddleX + 80.0) {
      vel = Offset(vel.dx, -vel.dy);
      pos = Offset(pos.dx, paddleTop - _ball.radius);
    }

    // Obstacles
    final before = _obController.obstacles.length;
    _obController.checkCollisions(pos, padding: _ball.radius);
    if (_obController.obstacles.length < before) {
      vel = Offset(vel.dx, -vel.dy);
      pos = _ball.position;
    }

    // Game Over
    if (pos.dy - _ball.radius >= size.height) vel = Offset.zero;

    final next = Ball(position: pos, velocity: vel, radius: _ballRadius);
    if (next.velocity == Offset.zero) {
      _controller.stop();
      context.read<GameCubit>().endGame(context.read<GameCubit>().state.score);
    }
    setState(() => _ball = next);
  }

  void _startGame() {
    _resetBall();
    _lastTime = DateTime.now();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _obController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (ctx, state) {
        if (state.status == GameStatus.playing) {
          _startGame();
        } else {
          _controller.stop();
        }
      },
      child: BlocBuilder<GameCubit, GameState>(
        builder: (ctx, state) => Stack(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => BallWidget(ball: _ball),
            ),
            for (final o in _obController.obstacles)
              AnimatedObstacleWidget(key: ValueKey(o.id), obstacle: o),
            if (state.status == GameStatus.newGame) const NewGameOverlay(),
            if (state.status == GameStatus.gameOver)
              GameOverOverlay(score: state.score),
            // Paddle
            const PaddleWidget(),
          ],
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
