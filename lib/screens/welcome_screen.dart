import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color onSecondaryColor = Theme.of(context).colorScheme.onSecondary;
    final Color textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    final Color headlineColor =
        Theme.of(context).textTheme.headlineMedium?.color ?? Colors.black;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final List<Color> gradientColors =
        isDarkMode
            ? [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.surfaceVariant,
              Theme.of(context).colorScheme.surface,
            ]
            : [Color(0xFF7EE6D9), Color(0xFFB2F7EF), Color(0xFFFFF6F6)];

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
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(isDarkMode ? 0.1 : 0.25),
              size: 60,
            ),
          ),
          Positioned(
            top: 100,
            right: 30,
            child: Icon(
              Icons.cloud,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(isDarkMode ? 0.1 : 0.18),
              size: 80,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.cloud,
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(
                    isDarkMode ? 0.1 : 0.18,
                  ),
                  size: 80,
                ),
                Icon(
                  Icons.cloud,
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(
                    isDarkMode ? 0.1 : 0.18,
                  ),
                  size: 60,
                ),
              ],
            ),
          ),
          FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).shadowColor.withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to Kids Tracker!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Peace of mind starts here. Track your kids easily and safely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: textColor),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: onPrimaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(fontSize: 18),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                              _showSnackbar('Welcome back!');
                            },
                            child: const Text('I have an account'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: secondaryColor,
                              side: BorderSide(color: secondaryColor, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                              _showSnackbar(
                                'Create a new account for your child!',
                              );
                            },
                            child: const Text('Create an account'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
