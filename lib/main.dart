import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
    return;
  }

  runApp(const GigsCourtApp());
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Firebase Error:\n$error',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class GigsCourtApp extends StatelessWidget {
  const GigsCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/logo.svg',
              width: 120,
              height: 120,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white : Colors.black,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 24),
            SvgPicture.asset(
              'assets/gigscourt-text.svg',
              width: 280,
              height: 50,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white : Colors.black,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
