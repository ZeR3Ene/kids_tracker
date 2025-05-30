import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
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
      Navigator.pushReplacementNamed(context, '/welcome');
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
                    style: GoogleFonts.nunito(
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