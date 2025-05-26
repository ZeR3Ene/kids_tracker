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
        scaffoldBackgroundColor: const Color(0xFF7EE6D9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF7EE6D9),
          primary: Color(0xFF7EE6D9),
          secondary: Color(0xFFFF6F61),
        ),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF7EE6D9),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(fontSize: 18, color: Colors.black),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Sans',
        scaffoldBackgroundColor: const Color(0xFF23272F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF23272F),
          primary: Color(0xFF23272F),
          secondary: Color(0xFFFF6F61),
          brightness: Brightness.dark,
        ),
        cardColor: const Color(0xFF2C313A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF23272F),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(fontSize: 18, color: Colors.white),
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            return const WelcomeScreen();
          }
        },
      ),
      routes: {
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
