import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../widgets/ball.dart';
import '../widgets/paddle.dart';
import '../widgets/obstacle.dart';
import '../game_state.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  late BallController ballController;
  late RotatingPaddleController leftPaddleController;
  late RotatingPaddleController rightPaddleController;
  late ObstacleController obstacleController;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screen =
          View.of(context).physicalSize / View.of(context).devicePixelRatio;

      setState(() {
        ballController = BallController(
            startPosition: Offset(screen.width / 2, screen.height / 2),
            speed: -400);

        final screenWidth = View.of(context).physicalSize.width /
            View.of(context).devicePixelRatio;

        leftPaddleController = RotatingPaddleController(
          vsync: this,
          position: Offset((screenWidth / 2) - 120, screen.height - 80),
          id: PaddleSide.left,
        );

        rightPaddleController = RotatingPaddleController(
          vsync: this,
          position: Offset((screenWidth / 2) + 120, screen.height - 80),
          id: PaddleSide.right,
        );
        obstacleController = ObstacleController(
          onHit: (o) => context.read<GameCubit>().incrementScore(),
          onUpdate: () => setState(() {}),
        );
        obstacleController.start();
      });
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    obstacleController.stop();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (ctx, state) {
        if (state.status == GameStatus.playing) {
          setState(() {});
          ballController.start();
        }
      },
      child: BlocBuilder<GameCubit, GameState>(
        builder: (ctx, state) {
          return KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  leftPaddleController.flipUp();
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  rightPaddleController.flipUp();
                }
              } else if (event is KeyUpEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  leftPaddleController.flipDown();
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  rightPaddleController.flipDown();
                }
              }
            },
            child: Stack(
              children: [
                if (state.status == GameStatus.playing)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Text(
                      '${state.score}',
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        color: Colors.white,
                        fontSize: 24,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.yellowAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                BallWidget(
                    controller: ballController,
                    leftPaddleController: leftPaddleController,
                    rightPaddleController: rightPaddleController,
                    obstacleController: obstacleController,
                    onGameOver: () {
                      context.read<GameCubit>().endGame(state.score);
                    }),
                RotatingPaddleWidget(controller: leftPaddleController),
                RotatingPaddleWidget(controller: rightPaddleController),
                for (final ob in obstacleController.obstacles)
                  AnimatedObstacleWidget(key: ValueKey(ob.id), obstacle: ob),
                if (state.status == GameStatus.newGame) const NewGameOverlay(),
                if (state.status == GameStatus.gameOver)
                  GameOverOverlay(score: state.score),
              ],
            ),
          );
        },
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
          const SizedBox(height: 150),
          Positioned(
            child: const PlayButton(),
          ),
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
              color: Colors.yellowAccent,
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
