import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RideDemoApp());
}

class RideDemoApp extends StatelessWidget {
  const RideDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const turquoise = Color(0xFF40E0D0);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorSchemeSeed: turquoise,

        scaffoldBackgroundColor: const Color(0xFFF6FEFD),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      home: const AuthGate(),
    );
  }
}