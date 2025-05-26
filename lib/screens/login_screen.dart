import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email to reset password.'),
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'Failed to send password reset email.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_error ?? 'Login failed')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Google Sign-In failed')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'An unexpected error occurred')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color onSecondaryColor = Theme.of(context).colorScheme.onSecondary;
    final Color textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    final Color hintColor = Theme.of(context).hintColor;
    final Color errorColor = Theme.of(context).colorScheme.error;
    final Color cardColor = Theme.of(context).cardColor;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final List<Color> gradientColors =
        isDarkMode
            ? [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.surfaceVariant,
              Theme.of(context).colorScheme.surface,
            ]
            : [Color(0xFF88E7D4), Color(0xFFB9F5E7), Color(0xFFE0F9EF)];

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
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).shadowColor.withOpacity(0.4),
                                blurRadius: 8,
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
                        'Login',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 20,
                          ),
                          hintStyle: TextStyle(color: hintColor),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter your email';
                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value))
                            return 'Enter a valid email';
                          return null;
                        },
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 20,
                          ),
                          hintStyle: TextStyle(color: hintColor),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Please enter your password';
                          return null;
                        },
                        style: TextStyle(color: textColor),
                      ),

                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: errorColor),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                          onPressed:
                              _loading
                                  ? null
                                  : () {
                                    if (_formKey.currentState!.validate()) {
                                      _login();
                                    }
                                  },
                          child:
                              _loading
                                  ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: onSecondaryColor,
                                    ),
                                  )
                                  : const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed:
                            _loading
                                ? null
                                : () => Navigator.pushNamed(context, '/signup'),
                        child: Text(
                          'Don\'t have an account? Sign Up',
                          style: TextStyle(color: secondaryColor),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 24.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey[400],
                                height: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                'Or',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey[400],
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _loading ? null : _signInWithGoogle,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFB9F5E7), Color(0xFFE0F9EF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/google_logo.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
