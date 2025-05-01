// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_size/window_size.dart';

import 'screens/game_page.dart';
// import 'screens/customize_page.dart';
import 'game_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle("Pinball");
    setWindowMinSize(const Size(360, 640));
    setWindowMaxSize(const Size(360, 640));
  }
  runApp(PinballApp());
}

class PinballApp extends StatelessWidget {
  const PinballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pinball',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.green,
          secondary: Colors.white,
          surface: Colors.black,
        ),
      ),
      builder: (context, child) => Center(
        child: SizedBox(width: 360, height: 640, child: child),
      ),
      initialRoute: '/game',
      routes: {
        '/game': (context) => BlocProvider(
              create: (_) => GameCubit(),
              child: const GamePage(),
            ),
        // '/customize': (context) => const CustomizePage(),
      },
    );
  }
}
