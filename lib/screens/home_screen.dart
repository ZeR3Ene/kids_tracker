import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data'; // Add this import at the top
import 'watch_settings_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const Color kCardBackground = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF333333);

class Activity {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final bool isAlert;

  Activity({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isAlert,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color kPrimaryCyan = Color(0xFF2EC4B6);
  static const Color kAccentCoral = Color(0xFFFF6F61);
  static const Color kSoftBackground = Color(0xFFF0FDFC);

  final user = FirebaseAuth.instance.currentUser;
  DatabaseReference get userRef =>
      FirebaseDatabase.instance.ref('users/${user?.uid}/children');
  Map<String, dynamic> watches = {};
  bool loading = true;
  Map<String, bool> childZoneStatus = {};
  Map<String, DateTime?> lastAlertTimes = {};
  Timer? _zoneMonitoringTimer;
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _watchesValueSubscription;
  StreamSubscription? _watchesChildRemovedSubscription;
  StreamSubscription? _sosSubscription;
  StreamSubscription? _watchesChildChangedSubscription;
  StreamSubscription? _watchesChildAddedSubscription;
  List<String> activityIds = [];
  List<Activity> activities = [];
  int _unreadNotifications = 0;
  final Map<String, bool> _previousSosState = {};
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Map<String, Timer?> _zoneAlertTimers = {};
  bool _isInitialLoad = true;
  String? _error;
  Timer? _sosAlertTimer;
  bool _isNavigatingToSettings = false;
  bool _isRemovingWatch = false;
  bool _deferFirebaseUpdates = false;
  Map<dynamic, dynamic>? _cachedWatchUpdateData;
  bool _isSOSAlertShowing = false;
  final Map<String, int> _sosNotificationIds =
      {}; // Map to store notification IDs by childId
  final Map<String, Timer?> _sosTimers =
      {}; // Map to store timers for repeating SOS notifications
  final ScrollController _sheetController = ScrollController();

  void _incrementNotificationCount() {
    setState(() {
      _unreadNotifications++;
    });
  }

  void _resetNotificationCount() {
    setState(() {
      _unreadNotifications = 0;
    });
  }

  void _showNotification(
    String title,
    String message, {
    bool isAlert = false,
    bool showSnackbar = true,
  }) {
    if (mounted) {
      final activity = Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        icon: isAlert ? Icons.warning : Icons.info,
        color: isAlert ? Colors.red : kPrimaryCyan,
        title: title,
        subtitle: message,
        time: _formatTime(DateTime.now()),
        isAlert: isAlert,
      );

      setState(() {
        activities.add(activity);
        _unreadNotifications++;
      });

      // Also show a native phone notification
      print('HomeScreen Log: Calling _showAppNotification for: $title');
      _showAppNotification(title, message, isAlert: isAlert);
    }
  }

  void _showZoneAlert(String childId, String childName) {
    if (mounted) {
      print(
        'HomeScreen Log: _showZoneAlert called for $childName (ID: $childId)',
      );
      // Show native notification for zone alert
      _showAppNotification(
        'Zone Alert',
        '$childName is outside safe zone',
        isAlert: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    print('HomeScreen Log: initState called.');
    setState(() {
      loading = false;
    });
    _initializeNotifications();
    _subscribeToAuthStateChanges();

    if (user != null) {
      _loadWatches();
    }
  }

  @override
  void dispose() {
    print('HomeScreen Log: dispose called.');
    _cancelSosTimers(); // Cancel all SOS timers on dispose
    _cancelDatabaseListeners();
    _sosAlertTimer?.cancel();
    super.dispose();
  }

  void _subscribeToAuthStateChanges() {
    print('HomeScreen Log: _subscribeToAuthStateChanges called.');
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      print(
        'HomeScreen Log: Auth state changed listener triggered. User is null: ${user == null}',
      );
      print('HomeScreen Log: Auth state changed. User: $user');
      _cancelDatabaseListeners();

      if (user != null) {
        print(
          'HomeScreen Log: User logged in (${user.uid}). Setting up database listeners...',
        );
        print(
          'HomeScreen Log: Calling _loadWatches() from _subscribeToAuthStateChanges.',
        );

        _migrateAlertNodes(user.uid);

        _loadWatches();
        _startZoneMonitoring();
        _sosSubscription = userRef.onValue.listen((event) {
          print('HomeScreen Log: SOS listener triggered!');
          if (mounted) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              data.forEach((key, value) {
                final watchData = value as Map<dynamic, dynamic>?;
                if (watchData != null) {
                  final childId = key.toString();
                  final currentSos = watchData['sos'] == true;
                  final previousSos = _previousSosState[childId] ?? false;

                  print(
                    'HomeScreen Log: SOS Listener Check: childId=$childId, currentSos=$currentSos, previousSos=$previousSos',
                  );

                  if (currentSos && !previousSos) {
                    final childName = watchData['name'] as String? ?? 'Child';
                    _showSOSAlertDialog(childName, childId, context);
                    // Add in-app notification for SOS trigger
                    _showNotification(
                      'SOS Alert',
                      '$childName sent an SOS signal!',
                      isAlert: true,
                    );
                    // Start repeating native SOS notification
                    _sosTimers[childId]?.cancel(); // Cancel any existing timer
                    _sosTimers[childId] = Timer.periodic(
                      const Duration(seconds: 4),
                      (_) {
                        print(
                          'HomeScreen Log: SOS timer triggered for $childId',
                        );
                        _showNativeSOSNotification(childId, childName);
                      },
                    );
                  } else if (!currentSos && previousSos) {
                    // SOS is cleared
                    print(
                      'HomeScreen Log: SOS cleared for $childId. Canceling timer.',
                    );
                    _sosTimers[childId]?.cancel();
                    _sosTimers.remove(childId);
                    _dismissNativeSOSNotification(
                      childId,
                    ); // Dismiss native notification
                  }
                  _previousSosState[childId] =
                      currentSos; // Update state after processing
                }
              });
            } else {
              _previousSosState.clear();
            }
          }
          print('HomeScreen Log: SOS listener setup block finished.');
        });
      } else {
        print(
          'HomeScreen Log: User logged out. Clearing data and canceling listeners...',
        );
        setState(() {
          watches = {};
          loading = false;
          childZoneStatus = {};
          lastAlertTimes = {};
          activities.clear();
          _unreadNotifications = 0;
          _previousSosState.clear();
          print('HomeScreen Log: State cleared due to logout.');
        });
      }
    });
    print('HomeScreen Log: _authStateSubscription assigned.');
  }

  void _cancelDatabaseListeners() {
    print('HomeScreen Log: _cancelDatabaseListeners called.');

    // Cancel all database subscriptions
    _watchesValueSubscription?.cancel();
    _watchesChildRemovedSubscription?.cancel();
    _sosSubscription?.cancel();
    _watchesChildChangedSubscription?.cancel();
    _watchesChildAddedSubscription?.cancel();

    // Clear references
    _watchesValueSubscription = null;
    _watchesChildRemovedSubscription = null;
    _sosSubscription = null;
    _watchesChildChangedSubscription = null;
    _watchesChildAddedSubscription = null;

    print('HomeScreen Log: All database listeners canceled.');
  }

  void _loadWatches() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('HomeScreen Log: _loadWatches: User not logged in');
      setState(() {
        watches = {};
        loading = false;
      });
      return;
    }

    print('HomeScreen Log: _loadWatches called. Current user UID: ${user.uid}');

    // Cancel any existing listener
    _watchesValueSubscription?.cancel();
    _watchesValueSubscription = null;

    final watchRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/children',
    );

    try {
      // First get initial data
      final snapshot = await watchRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          watches = _convertToMap(data);
          loading = false;
        });
      } else {
        setState(() {
          watches = {};
          loading = false;
        });
      }

      // Then set up listener for updates
      _watchesValueSubscription = watchRef.onValue.listen((event) {
        if (mounted) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            setState(() {
              watches = _convertToMap(data);
            });
          } else {
            setState(() {
              watches = {};
            });
          }
        }
      });

      // Set up listeners for child events
      _watchesChildAddedSubscription = watchRef.onChildAdded.listen(
        (event) {
          if (mounted) {
            final childId = event.snapshot.key;
            final childData = event.snapshot.value as Map<dynamic, dynamic>?;
            if (childId != null && childData != null) {
              print('HomeScreen Log: onChildAdded triggered for $childId');
              // Check if the watch already exists to avoid duplicate handling on initial load
              if (!watches.containsKey(childId)) {
                final Map<String, dynamic> convertedData = _convertToMap(
                  childData,
                );
                setState(() {
                  watches[childId] = convertedData;
                });
                _handleWatchAdded(childId, convertedData);
              } else {
                // This case might happen on hot reload if the listener isn't properly cancelled
                print(
                  'HomeScreen Log: onChildAdded triggered for existing watch: $childId',
                );
              }
            }
          }
        },
        onError: (error) {
          print('HomeScreen Log: onChildAdded error: $error');
        },
      );

      _watchesChildChangedSubscription = watchRef.onChildChanged.listen(
        (event) {
          if (mounted) {
            final childId = event.snapshot.key;
            final childData = event.snapshot.value as Map<dynamic, dynamic>?;
            if (childId != null && childData != null) {
              print('HomeScreen Log: onChildChanged triggered for $childId');
              final Map<String, dynamic> convertedData = _convertToMap(
                childData,
              );

              // Check if 'safe' status changed specifically
              final previousSafeStatus = watches[childId]?['safe'] as bool?;
              final currentSafeStatus = convertedData['safe'] as bool?;

              setState(() {
                watches[childId] = convertedData;
              });

              if (previousSafeStatus != currentSafeStatus) {
                print('HomeScreen Log: Safe status changed for $childId');
                _handleStatusChange(childId, convertedData);
              }
              // Note: Other changes (like name, color) are handled by the state update above
            }
          }
        },
        onError: (error) {
          print('HomeScreen Log: onChildChanged error: $error');
        },
      );

      _watchesChildRemovedSubscription = watchRef.onChildRemoved.listen(
        (event) {
          if (mounted) {
            final childId = event.snapshot.key;
            print('HomeScreen Log: onChildRemoved triggered for $childId');
            if (childId != null) {
              setState(() {
                watches.remove(childId);
              });
              _handleWatchRemoved(childId);
            }
          }
        },
        onError: (error) {
          print('HomeScreen Log: onChildRemoved error: $error');
        },
      );

      print('HomeScreen Log: Watch child event listeners set up.');
    } catch (e) {
      print('HomeScreen Log: Error in _loadWatches: $e');
      setState(() {
        loading = false;
      });
    }
  }

  void _startZoneMonitoring() {
    _zoneMonitoringTimer?.cancel();
    print(
      'HomeScreen Log: _zoneMonitoringTimer canceled as onValue listener is used.',
    );
  }

  void _handleWatchAdded(String childId, Map<String, dynamic> childData) {
    print('HomeScreen Log: _handleWatchAdded called for $childId.');
    final name = childData['name'] as String? ?? 'Child';
    final title = 'Watch Added';
    final message = 'Added watch for $name';
    _showNotification(title, message, isAlert: false);
    _showAppNotification(title, message, isAlert: false);
  }

  void _handleWatchRemoved(String childId) {
    print('HomeScreen Log: _handleWatchRemoved called for $childId.');
    if (mounted) {
      final title = 'Watch Removed';
      final message = 'Watch removed';
      _showNotification(title, message, isAlert: false);
      _showAppNotification(title, message, isAlert: false);
    }
  }

  void _handleStatusChange(String childId, Map<String, dynamic> childData) {
    print(
      'HomeScreen Log: _handleStatusChange called for $childId. isSafe: ${childData['safe']}',
    );
    final name = childData['name'] as String? ?? 'Child';
    final isSafe = childData['safe'] as bool? ?? true;

    if (mounted) {
      setState(() {
        childZoneStatus[childId] = isSafe;
        print(
          'HomeScreen Log: _handleStatusChange setState called. $childId safe status: ${childZoneStatus[childId]}',
        );
      });
    }

    if (!isSafe) {
      final title = 'Zone Alert';
      final message = '$name is outside safe zone';

      if (_zoneAlertTimers[childId] == null ||
          !_zoneAlertTimers[childId]!.isActive) {
        print(
          'HomeScreen Log: Starting zone alert timer for $name (ID: $childId)',
        );
        _zoneAlertTimers[childId] = Timer.periodic(const Duration(seconds: 10), (
          timer,
        ) {
          print(
            'HomeScreen Log: Zone alert timer triggered for $name (ID: $childId)',
          );
          // Show native notification for zone alert
          if (mounted) {
            print(
              'HomeScreen Log: Showing native zone alert notification for $childId',
            ); // Log before showing notification
            _showAppNotification(title, message, isAlert: true);
          }
        });
        _showNotification(title, message, isAlert: true);
        _showAppNotification(title, message, isAlert: true);
        print('HomeScreen Log: Zone alert notification shown for $childId.');
      }
    } else {
      if (_zoneAlertTimers[childId] != null &&
          _zoneAlertTimers[childId]!.isActive) {
        print(
          'HomeScreen Log: Canceling zone alert timer for $name (ID: $childId)',
        );
        _zoneAlertTimers[childId]?.cancel();
        _zoneAlertTimers.remove(childId);
      }
      // Show notification for safe zone
      final title = 'Safe Zone';
      final message = '$name is now in safe zone';
      _showNotification(title, message, isAlert: false);
      _showAppNotification(title, message, isAlert: false);
      print('HomeScreen Log: Safe zone notification shown for $childId.');
    }
  }

  bool _isInSafeZone(
    double currentLat,
    double currentLng,
    double zoneLat,
    double zoneLng,
    double zoneRadius,
  ) {
    const earthRadius = 6371000;
    final dLat = (currentLat - zoneLat).abs() * (pi / 180);
    final dLng = (currentLng - zoneLng).abs() * (pi / 180);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(zoneLat * (pi / 180)) *
            cos(currentLat * (pi / 180)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return distance <= zoneRadius;
  }

  Map<String, dynamic> _getRandomLocation() {
    final random = Random();
    return {
      'lat': 32.4617 + (random.nextDouble() - 0.5) * 0.01,
      'lng': 35.3006 + (random.nextDouble() - 0.5) * 0.01,
    };
  }

  void _addActivity(Activity activity) {
    setState(() {
      activities.add(activity);
      print('HomeScreen Log: Activity added: ${activity.title}');
    });
  }

  Future<void> _addExampleWatches() async {
    print('HomeScreen Log: _addExampleWatches called.');
    final exampleData = {
      'child_1': {
        'name': 'Ali',
        'color': '#2EC4B6',
        'safe': true,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'avatar': null,
        'safeZone': {'lat': 32.4620, 'lng': 35.3010, 'radius': 120},
        'location': {'lat': 32.4620, 'lng': 35.3010},
      },
      'child_2': {
        'name': 'Lina',
        'color': '#FF6F61',
        'safe': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch - 60000 * 30,
        'avatar': null,
        'safeZone': {'lat': 32.4615, 'lng': 35.3000, 'radius': 100},
        'location': {'lat': 32.4615, 'lng': 35.3000},
      },
    };
    await userRef.update(exampleData);
    if (mounted) {
      setState(() {
        exampleData.forEach((key, value) {
          watches[key] = value;
        });
      });
    }
    _showNotification('Example Watches', 'Example watches added');
    print('HomeScreen Log: Example watches added.');
  }

  void _removeActivity(String id) {
    setState(() {
      activities.removeWhere((activity) => activity.id == id);
      print('HomeScreen Log: Activity removed with id: $id');
    });
  }

  Future<void> _showSOSAlertDialog(
    String childName,
    String childId,
    BuildContext context,
  ) async {
    if (_isSOSAlertShowing) {
      print('HomeScreen Log: SOS dialog is already showing. Returning.');
      return;
    }

    _isSOSAlertShowing = true;

    // Show persistent alert dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Make dialog non-dismissible
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.red, // Set background to red
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'SOS Alert!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ), // White text for contrast
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.white, size: 60),
                SizedBox(height: 16),
                Text(
                  '$childName has triggered an SOS and may be unsafe.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Clear SOS state
                  setState(() {
                    // _isSOSAlertShowing = false; // Will be set to false by the listener when Firebase updates
                    _sosAlertTimer?.cancel();
                  });

                  // Navigate back to map screen
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }

                  // Clear SOS state in Firebase
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    FirebaseDatabase.instance
                        .ref('users/${user.uid}/children/$childId')
                        .update({'sos': false})
                        .then((_) {
                          print('SOS state cleared for $childId');
                          // Update local state and show in-app notification after Firebase update
                          if (mounted) {
                            setState(() {
                              if (watches.containsKey(childId)) {
                                watches[childId]['sos'] = false;
                                print(
                                  'HomeScreen Log: Local SOS state updated for $childId',
                                );
                              }
                            });
                          }
                        })
                        .catchError((error) {
                          print('Error clearing SOS state: $error');
                        });
                  }
                  _isSOSAlertShowing =
                      false; // Ensure flag is reset after attempt to clear Firebase
                },
                child: Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _showNativeSOSNotification(String childId, String childName) async {
    final notificationId = childId.hashCode;
    _sosNotificationIds[childId] = notificationId; // Store notification ID

    final vibrationPattern = Int64List.fromList(<int>[0, 1000, 500, 1000]);
    final AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'sos_channel_id',
      'SOS Alerts',
      channelDescription: 'Notifications for SOS signals',
      importance: Importance.max,
      priority: Priority.high,
      sound: null, // Use default system alert sound
      playSound: true,
      ongoing: true, // Make it persistent
      autoCancel: false, // Don't auto cancel when clicked
      vibrationPattern: vibrationPattern,
      enableVibration: true,
      color: const Color(0xFFFF0000), // Red color for SOS
      colorized:
          true, // Attempt to colorize the notification background (may vary by device)
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin
        .show(
          0,
          'SOS Alert',
          '$childName sent an SOS signal!',
          platformChannelSpecifics,
          payload: childId, // Include childId as payload
        )
        .then((_) {
          print(
            'Native SOS notification shown for $childName (ID: $childId), ID: $notificationId.',
          );
        })
        .catchError((error) {
          print(
            'Error showing native SOS notification for $childName (ID: $childId): $error',
          );
        });
  }

  void _dismissNativeSOSNotification(String childId) async {
    if (_sosNotificationIds.containsKey(childId)) {
      await flutterLocalNotificationsPlugin.cancel(
        _sosNotificationIds[childId]!,
      );
      print('Native SOS notification dismissed for $childId.');
      _sosNotificationIds.remove(childId);
    }
  }

  void _showNotifications() {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: kSoftBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Notifications',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      activities
                          .map(
                            (activity) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kCardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    activity.icon,
                                    color:
                                        activity.isAlert
                                            ? kAccentCoral
                                            : kPrimaryCyan,
                                    size: 24,
                                  ),
                                  title: Text(
                                    activity.title,
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          activity.isAlert
                                              ? kAccentCoral
                                              : kTextDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    activity.subtitle,
                                    style: GoogleFonts.nunito(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  trailing: Text(
                                    activity.time,
                                    style: GoogleFonts.nunito(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {
                        activities.clear();
                        _unreadNotifications = 0;
                      });
                    }
                  },
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.nunito(
                      color: kAccentCoral,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {
                        _unreadNotifications = 0;
                      });
                    }
                  },
                  child: Text(
                    'Close',
                    style: GoogleFonts.nunito(
                      color: kPrimaryCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _showAppNotification(
    String title,
    String message, {
    bool isAlert = false,
  }) async {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'app_channel_id',
          'General Notifications',
          channelDescription: 'General app notifications',
          importance: isAlert ? Importance.high : Importance.low,
          priority: isAlert ? Priority.high : Priority.low,
          sound: null,
          playSound: true,
          vibrationPattern: Int64List.fromList(<int>[0, 1000, 500, 1000]),
          enableVibration: true,
          color: isAlert ? const Color(0xFFFF0000) : null,
        );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails();

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    final int notificationId =
        DateTime.now().millisecondsSinceEpoch %
        2000000000; // Unique ID for general notifications

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      message,
      notificationDetails,
    );
    print('App notification shown: $title');
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen Log: build called.');
    return Scaffold(
      backgroundColor: kSoftBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryCyan,
        automaticallyImplyLeading: false,
        elevation: 0,
        leading: IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        _unreadNotifications.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            if (mounted) {
              setState(() {
                _unreadNotifications = 0;
              });
              _showNotifications();
            }
          },
        ),
        title: Text(
          '',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/generalSettings'),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            _resetNotificationCount();
          }
          return true;
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kPrimaryCyan,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kids Tracker',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Keep your kids safe',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (watches.isEmpty && loading)
                            const Center(child: CircularProgressIndicator()),
                          ...watches.entries.map((entry) {
                            final watchId = entry.key;
                            final watchData = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: WatchCard(
                                key: ValueKey(watchId),
                                watchId: watchId,
                                data: watchData,
                                onConnect:
                                    () => Navigator.pushNamed(
                                      context,
                                      '/pair',
                                      arguments: watchId,
                                    ),
                                onSettings:
                                    () => _navigateToWatchSettings(
                                      context,
                                      watchId: watchId,
                                    ),
                                primaryColor: kPrimaryCyan,
                                accentColor: kAccentCoral,
                                timeFormatter: _formatTime,
                              ),
                            );
                          }).toList(),
                          if (!loading && watches.length < 2)
                            ...List.generate(
                              2 - watches.length,
                              (index) => Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: WatchCard(
                                  key: ValueKey('not_connected_${index + 1}'),
                                  watchId:
                                      'new_watch_${watches.length + index + 1}',
                                  data: {},
                                  onConnect:
                                      () =>
                                          Navigator.pushNamed(context, '/pair'),
                                  onSettings: () {},
                                  primaryColor: kPrimaryCyan,
                                  accentColor: kAccentCoral,
                                  timeFormatter: _formatTime,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Features',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CardTile(
                      icon: Icons.map,
                      color: kPrimaryCyan,
                      title: 'View Map',
                      subtitle: 'See your kids on the map',
                      onTap: () => Navigator.pushNamed(context, '/map'),
                    ),
                    const SizedBox(height: 24),
                    if (!loading || watches.isEmpty)
                      ElevatedButton.icon(
                        onPressed: _addExampleWatches,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Example Watches"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryCyan,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 24,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          () => _simulateSafeZoneChange(
                            childId: 'child_1',
                            isSafe: true,
                          ), // Simulate inside safe zone
                      child: const Text('Simulate Watch 1 Inside Safe Zone'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _simulateLinaOutsideZone,
                      child: const Text('Trigger SOS (Example Watch 1)'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _triggerSOSExample() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in. Cannot trigger SOS.');
      return;
    }
    final childId = 'child_1';
    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/children/$childId')
          .update({'sos': true});
      print('SOS triggered for $childId');
    } catch (e) {
      print('Error triggering SOS: $e');
    }
  }

  Future<void> _simulateLinaOutsideZone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in. Cannot simulate Lina outside zone.');
      return;
    }
    final childId = 'child_2';
    final childRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/children/$childId',
    );

    print('Attempting to read current safe status for $childId');
    try {
      final snapshot = await childRef.child('safe').get();
      bool currentSafeStatus = snapshot.value as bool? ?? true;
      print('Current safe status for $childId: $currentSafeStatus');

      final newSafeStatus = !currentSafeStatus;
      final updatePath = 'users/${user.uid}/children/$childId';
      final updateValue = {'safe': newSafeStatus};

      print(
        'Attempting to update Firebase at path: $updatePath with value: $updateValue',
      );
      await FirebaseDatabase.instance.ref(updatePath).update(updateValue);
      print('Firebase update for $childId safe status successful');

      print('Simulated $childId status toggled to: $newSafeStatus');
    } catch (e) {
      print('Error simulating $childId safe zone status: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print('Local notifications initialized.');
  }

  Future<void> _migrateAlertNodes(String userId) async {
    final DatabaseReference oldSosRef = FirebaseDatabase.instance.ref(
      'users/$userId/children/SOS Alert',
    );
    final DatabaseReference newSosRef = FirebaseDatabase.instance.ref(
      'users/$userId/SOS Alert',
    );
    final DatabaseReference oldZoneRef = FirebaseDatabase.instance.ref(
      'users/$userId/children/Zone Alert',
    );
    final DatabaseReference newZoneRef = FirebaseDatabase.instance.ref(
      'users/$userId/Zone Alert',
    );

    print('Attempting to migrate alert nodes for user: $userId');

    try {
      final sosSnapshot = await oldSosRef.get();
      if (sosSnapshot.exists && sosSnapshot.value != null) {
        print('SOS Alert found at old location, migrating...');
        await newSosRef.set(sosSnapshot.value);
        await oldSosRef.remove();
        print('SOS Alert node migrated successfully.');
      } else {
        print('SOS Alert not found at old location or already migrated.');
      }
    } catch (e) {
      print('Error migrating SOS Alert node: $e');
    }

    try {
      final zoneSnapshot = await oldZoneRef.get();
      if (zoneSnapshot.exists && zoneSnapshot.value != null) {
        print('Zone Alert found at old location, migrating...');
        await newZoneRef.set(zoneSnapshot.value);
        await oldZoneRef.remove();
        print('Zone Alert node migrated successfully.');
      } else {
        print('Zone Alert not found at old location or already migrated.');
      }
    } catch (e) {
      print('Error migrating Zone Alert node: $e');
    }

    print('HomeScreen Log: Alert node migration process finished.');
  }

  void _navigateToWatchSettings(
    BuildContext context, {
    required String watchId,
  }) {
    print('HomeScreen Log: _navigateToWatchSettings called for $watchId.');

    // Ensure we're not already navigating
    if (_isNavigatingToSettings) return;

    setState(() {
      _isNavigatingToSettings = true;
    });

    try {
      // Use a local variable to capture the context
      final localContext = context;

      Navigator.push(
            localContext,
            MaterialPageRoute(
              builder:
                  (context) => WatchSettingsScreen(
                    watchId: watchId,
                    getWatchData: (id) => _convertToMap(watches[id]),
                    onRemove: () => _removeWatch(watchId),
                  ),
            ),
          )
          .then((result) {
            // Only update state if we're still mounted
            if (mounted) {
              setState(() {
                _isNavigatingToSettings = false;
              });

              // If updatedData was returned from settings, apply it directly
              if (result != null && result is Map) {
                print(
                  'HomeScreen Log: Received updated data from settings: $result',
                );
                // Use _convertToMap to ensure all nested maps are Map<String, dynamic>
                final Map<String, dynamic> stronglyTypedUpdatedData =
                    _convertToMap(result);

                if (mounted) {
                  setState(() {
                    watches[watchId] = stronglyTypedUpdatedData;
                    print(
                      'HomeScreen Log: Applied strongly typed updated data for $watchId: $watches',
                    );
                  });
                }
              }

              if (_cachedWatchUpdateData != null) {
                // Process cached data
                print(
                  'HomeScreen Log: Processing cached data: $_cachedWatchUpdateData',
                );
                // Apply cached data to watches
                if (mounted) {
                  setState(() {
                    watches = {...watches, ..._cachedWatchUpdateData!};
                    print(
                      'HomeScreen Log: Applied cached data to watches: $watches',
                    );
                  });
                }
                _cachedWatchUpdateData = null; // Clear cached data
              }
            }
          })
          .catchError((error) {
            print('HomeScreen Log: Error in navigation: $error');
            if (mounted) {
              setState(() {
                _isNavigatingToSettings = false;
              });
            }
          });
    } catch (error) {
      print('HomeScreen Log: Error in _navigateToWatchSettings: $error');
      if (mounted) {
        setState(() {
          _isNavigatingToSettings = false;
        });
      }
    }
  }

  void _removeWatch(String watchId) {
    print('HomeScreen Log: _removeWatch called for $watchId.');

    // Ensure we're not already removing
    if (_isRemovingWatch) return;

    setState(() {
      _isRemovingWatch = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('HomeScreen Log: _removeWatch failed - User not logged in');
        return;
      }

      final watchRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/children/$watchId',
      );

      watchRef
          .remove()
          .then((_) {
            if (mounted) {
              setState(() {
                watches.remove(watchId);
                _isRemovingWatch = false;
              });
            }
          })
          .catchError((error) {
            print('HomeScreen Log: Error removing watch: $error');
            if (mounted) {
              setState(() {
                _isRemovingWatch = false;
              });
            }
          });
    } catch (error) {
      print('HomeScreen Log: Error in _removeWatch: $error');
      if (mounted) {
        setState(() {
          _isRemovingWatch = false;
        });
      }
    }
  }

  Map<String, dynamic> _convertToMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.fromEntries(
        data.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            // Recursively call _convertToMap for nested maps
            entry.value is Map ? _convertToMap(entry.value) : entry.value,
          ),
        ),
      );
    }
    // Return an empty map if the input data is not a map or is null
    return {};
  }

  void _cancelSosTimers() {
    print('HomeScreen Log: Cancelling all SOS timers.');
    _sosTimers.forEach((childId, timer) {
      timer?.cancel();
      print('HomeScreen Log: Canceled SOS timer for $childId.');
    });
    _sosTimers.clear();
  }
}

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371000;
  final double latRad1 = lat1 * pi / 180;
  final double lonRad1 = lon1 * pi / 180;
  final double latRad2 = lat2 * pi / 180;
  final double lonRad2 = lon2 * pi / 180;

  final double dLat = latRad2 - latRad1;
  final double dLon = lonRad2 - lonRad1;

  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(latRad1) * cos(latRad2) * sin(dLon / 2) * sin(dLon / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

class WatchCard extends StatelessWidget {
  final String watchId;
  final Map? data;
  final VoidCallback onConnect;
  final VoidCallback onSettings;
  final Color primaryColor;
  final Color accentColor;
  final String Function(DateTime) timeFormatter;

  const WatchCard({
    super.key,
    required this.watchId,
    required this.data,
    required this.onConnect,
    required this.onSettings,
    required this.primaryColor,
    required this.accentColor,
    required this.timeFormatter,
  });

  int _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return int.parse(hex, radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    print('Building WatchCard for watchId: $watchId');
    print('WatchCard received data: $data');
    final isConnected = data != null && data!['location'] != null;
    final colorHex =
        (isConnected && data!['color'] != null)
            ? data!['color'] as String
            : '#2EC4B6';
    print('Determined colorHex: $colorHex');
    final color = Color(_hexToColor(colorHex));
    final avatar =
        isConnected && data?['avatar'] != null
            ? CircleAvatar(
              backgroundImage: NetworkImage(data?['avatar']),
              radius: 28,
            )
            : CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 28,
              child: Icon(Icons.watch, color: color, size: 32),
            );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 8),
          Text(
            isConnected ? (data?['name'] ?? 'Watch') : 'Not Connected',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              color: kTextDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (isConnected) ...[
            Text(
              data?['lastSeen'] != null
                  ? 'Last seen: ${timeFormatter(DateTime.fromMillisecondsSinceEpoch(data?['lastSeen']))}'
                  : 'No recent location',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[700]),
            ),
            Text(
              data?['safe'] == true ? 'Status: Safe' : 'Status: Outside zone',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: data?['safe'] == true ? primaryColor : accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                elevation: 0,
              ),
              child: const Text('Settings'),
            ),
          ] else
            ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                elevation: 0,
              ),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}

class CardTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const CardTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(
          title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: GoogleFonts.nunito()),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);

  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} mins ago';
  if (difference.inDays < 1) return '${difference.inHours} hours ago';
  return '${difference.inDays} days ago';
}
