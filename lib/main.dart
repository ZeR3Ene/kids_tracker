import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/qr_pair_screen.dart';
import 'screens/child_info_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'PASTE_YOUR_API_KEY_HERE',
        appId: 'PASTE_YOUR_APP_ID_HERE',
        messagingSenderId: 'PASTE_YOUR_MESSAGING_SENDER_ID_HERE',
        projectId: 'PASTE_YOUR_PROJECT_ID_HERE',
        authDomain: 'PASTE_YOUR_AUTH_DOMAIN_HERE',
        databaseURL: 'PASTE_YOUR_DATABASE_URL_HERE',
        storageBucket: 'PASTE_YOUR_STORAGE_BUCKET_HERE',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  runApp(AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      themeMode: _themeMode,
      toggleTheme: toggleTheme,
      child: MyApp(themeMode: _themeMode),
    );
  }
}

class ThemeSwitcher extends InheritedWidget {
  final ThemeMode themeMode;
  final VoidCallback toggleTheme;
  const ThemeSwitcher({
    super.key,
    required this.themeMode,
    required this.toggleTheme,
    required super.child,
  });
  static ThemeSwitcher of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeSwitcher>()!;
  @override
  bool updateShouldNotify(ThemeSwitcher oldWidget) =>
      themeMode != oldWidget.themeMode;
}

class MyApp extends StatelessWidget {
  final ThemeMode themeMode;
  const MyApp({super.key, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7EE6D9),
          primary: const Color(0xFF7EE6D9),
          secondary: const Color(0xFFFF6F61),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFF7EE6D9),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF7EE6D9),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
          titleLarge: TextStyle(color: Colors.black87),
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2EC4B6),
          primary: const Color(0xFF2EC4B6),
          secondary: const Color(0xFFFF6F61),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2EC4B6),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white70),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2EC4B6),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      themeMode: themeMode,
      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/pair': (context) => const QRPairScreen(),
        '/child_info': (context) => const ChildInfoScreen(),
        '/map': (context) => const MapScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/generalSettings': (context) => const SettingsScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final List<Color> gradientColors = isDarkMode
        ? [
      Theme.of(context).scaffoldBackgroundColor,
      Theme.of(context).colorScheme.surfaceVariant,
      Theme.of(context).colorScheme.surface,
    ]
        : [
      const Color(0xFF7EE6D9),
      const Color(0xFFB2F7EF),
      const Color(0xFFFFF6F6),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: Icon(
              Icons.cloud,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(
                isDarkMode ? 0.1 : 0.25,
              ),
              size: 60,
            ),
          ),
          Positioned(
            top: 100,
            right: 30,
            child: Icon(
              Icons.cloud,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(
                isDarkMode ? 0.1 : 0.18,
              ),
              size: 80,
            ),
          ),
          FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Kids Tracker',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}