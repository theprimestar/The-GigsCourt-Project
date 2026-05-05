import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const GigsCourtApp());
}

class GigsCourtApp extends StatelessWidget {
  const GigsCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
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
