import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/verify_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        final idToken = await user.getIdToken(false);
        return idToken;
      },
    );
  } catch (e) {
    runApp(ErrorApp(error: 'Supabase Error:\n$e'));
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
              '$error',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class GigsCourtApp extends StatefulWidget {
  const GigsCourtApp({super.key});

  @override
  State<GigsCourtApp> createState() => _GigsCourtAppState();
}

class _GigsCourtAppState extends State<GigsCourtApp> {
  String _screen = 'splash';

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _screen = 'auth');
      return;
    }

    await user.reload();
    final freshUser = FirebaseAuth.instance.currentUser;

    if (freshUser == null) {
      setState(() => _screen = 'auth');
      return;
    }

    if (!freshUser.emailVerified) {
      setState(() => _screen = 'verify');
    } else {
      setState(() => _screen = 'home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case 'splash':
        return const SplashScreen();
      case 'auth':
        return AuthScreen(
          onAuthenticated: () => setState(() => _screen = 'home'),
          onVerifyEmail: () => setState(() => _screen = 'verify'),
        );
      case 'verify':
        return VerifyEmailScreen(
          onVerified: () => setState(() => _screen = 'home'),
          onBack: () => setState(() => _screen = 'auth'),
        );
      case 'home':
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : const Color(0xFFF7F6F4),
          body: const Center(
            child: Text('Home Screen — Coming Soon'),
          ),
        );
      default:
        return const SplashScreen();
    }
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
              width: 80,
              height: 80,
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
