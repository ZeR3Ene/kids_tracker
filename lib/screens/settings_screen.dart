import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  final bool _editingName = false;
  String? _name;
  String? _email;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _name = user?.displayName ?? 'Parent';
    _email = user?.email ?? '';
  }

  void _editName() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Name'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (newName != null && newName.isNotEmpty && newName != _name) {
      setState(() => _name = newName);
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name updated!')));
      }
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in or email not available.'),
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send password reset email.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    child: Icon(
                      Icons.person,
                      size: 36,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _name ?? '',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 20,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed: _editName,
                              tooltip: 'Edit Name',
                            ),
                          ],
                        ),
                        Text(
                          _email ?? '',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListTile(
              leading: Icon(
                Icons.lock_reset,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                'Reset Password',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: _resetPassword,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SwitchListTile(
              title: Text(
                'Dark Mode',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: ThemeSwitcher.of(context).themeMode == ThemeMode.dark,
              onChanged: (_) => ThemeSwitcher.of(context).toggleTheme(),
              secondary: Icon(
                Icons.dark_mode,
                color: Theme.of(context).iconTheme.color,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SwitchListTile(
              title: Text(
                'Enable Notifications',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: notifications,
              onChanged: (v) {
                setState(() => notifications = v);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      v ? 'Notifications enabled' : 'Notifications disabled',
                    ),
                  ),
                );
              },
              secondary: Icon(
                Icons.notifications_active,
                color: Theme.of(context).iconTheme.color,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F61),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 32,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
    );
  }
}
