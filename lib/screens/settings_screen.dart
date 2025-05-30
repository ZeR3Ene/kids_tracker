import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import '../main.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/responsive_utils.dart';
import '../widgets/widgets.dart';

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
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref('users/${user.uid}/settings/notificationsEnabled')
              .get();
      if (snapshot.exists) {
        setState(() {
          notifications = snapshot.value as bool? ?? true;
        });
        print('Settings Log: Loaded notificationsEnabled: $notifications');
      } else {
        print(
          'Settings Log: Notification setting not found in Firebase, using default: $notifications',
        );
      }
    } catch (e) {
      print('Settings Log: Error loading notification setting: $e');
    }
  }

  Future<void> _saveNotificationSetting(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/notificationsEnabled')
          .set(value);
      print('Settings Log: Saved notificationsEnabled: $value');
    } catch (e) {
      print('Settings Log: Error saving notification setting: $e');
    }
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
    final responsive = ResponsiveUtils(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverAppBar(
              backgroundColor: theme.appBarTheme.backgroundColor,
              pinned: true,
              floating: false,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.appBarTheme.foregroundColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                centerTitle: true,
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  size: 28,
                  color: theme.appBarTheme.foregroundColor,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Profile Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        blurRadius: 15,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Profile Avatar
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                        SizedBox(height: 16),
                        // Name and Email
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _name ?? 'Parent',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _email ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        // Edit Profile Button
                        Container(
                          width: 140,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: _editName,
                            child: Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Settings List
            SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: responsive.spacing(0.04)),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Theme Setting
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.dark_mode,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: Switch(
                          value:
                              ThemeSwitcher.of(context).themeMode ==
                              ThemeMode.dark,
                          onChanged: (value) {
                            ThemeSwitcher.of(context).toggleTheme();
                          },
                          activeColor: theme.colorScheme.primary,
                          activeTrackColor: theme.colorScheme.primary
                              .withOpacity(0.3),
                          inactiveThumbColor: theme.colorScheme.onSurface
                              .withOpacity(0.3),
                          inactiveTrackColor: theme.colorScheme.onSurface
                              .withOpacity(0.1),
                        ),
                      ),

                      // Notifications Setting
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.notifications,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: Switch(
                          value: notifications,
                          onChanged: (value) async {
                            setState(() {
                              notifications = value;
                            });
                            await _saveNotificationSetting(value);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? 'Notifications enabled'
                                        : 'Notifications disabled',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          activeColor: theme.colorScheme.primary,
                          activeTrackColor: theme.colorScheme.primary
                              .withOpacity(0.3),
                          inactiveThumbColor: theme.colorScheme.onSurface
                              .withOpacity(0.3),
                          inactiveTrackColor: theme.colorScheme.onSurface
                              .withOpacity(0.1),
                        ),
                      ),

                      // Security Setting
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.lock_reset,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 24,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        onTap: _resetPassword,
                      ),

                      // Account Setting
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.error.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.logout,
                            color: theme.colorScheme.error,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 24,
                          color: theme.colorScheme.error.withOpacity(0.4),
                        ),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
