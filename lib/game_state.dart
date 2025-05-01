import 'package:flutter_bloc/flutter_bloc.dart';

enum GameStatus { newGame, playing, gameOver }

class GameState {
  final GameStatus status;
  final int score;

  const GameState({required this.status, this.score = 0});

  GameState copyWith({GameStatus? status, int? score}) {
    return GameState(
      status: status ?? this.status,
      score: score ?? this.score,
    );
  }
}

class GameCubit extends Cubit<GameState> {
  GameCubit() : super(const GameState(status: GameStatus.newGame));

  /// Starts a new game
  void startGame() => emit(const GameState(status: GameStatus.playing));

  /// Ends the current game with a final score
  void endGame(int finalScore) =>
      emit(GameState(status: GameStatus.gameOver, score: finalScore));

  /// Resets to a new‐game state
  void resetGame() =>
      emit(const GameState(status: GameStatus.newGame, score: 0));

  /// Updates score
  void incrementScore() {
    emit(state.copyWith(score: state.score + 1));
  }
}
