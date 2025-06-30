import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'watch_settings_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/activity_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kPrimaryCyan = Color(0xFF2EC4B6);
const Color kAccentCoral = Color(0xFFFF6F61);
const Color kSoftBackground = Color(0xFFF0FDFC);
const Color kCardBackground = Color(0xFFFFFFFF);

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
  late User? user;
  late DatabaseReference _childrenRef;
  late DatabaseReference _watchesRef;
  Timer? _refreshTimer;
  StreamSubscription? _childrenSubscription;
  Map<String, StreamSubscription> _watchSubscriptions = {};
  Map<String, bool?> _isSOSAlertShowing = {};
  Map<String, Timer?> _sosAlertTimers = {};
  Map<String, int> _sosNotificationIds = {};
  Map<String, Timer?> _sosTimers = {};
  bool _isNavigatingToSettings = false;
  bool _isRemovingWatch = false;
  Map<dynamic, dynamic>? _cachedWatchUpdateData;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Map<String, dynamic> _childrenData = {};
  bool _loading = true;
  String? _error;
  bool _notificationsEnabled = true;
  StreamSubscription? _notificationSettingsSubscription;

  List<Activity> _activities = [];
  int _unreadNotifications = 0;

  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, StreamSubscription?> _sosActiveSubscriptions = {};
  Map<String, bool> _isFirstSOSSync = {};
  Map<String, bool?> _lastSOSValue = {};

  Map<String, StreamSubscription?> _safeSubscriptions = {};
  Map<String, bool?> _lastSafeValue = {};

  DateTime? _suppressSafeZoneNotificationsUntil;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _childrenRef = FirebaseDatabase.instance.ref('users/${user!.uid}/children');
    _watchesRef = FirebaseDatabase.instance.ref('watches');

    _initializeNotifications();

    _initializeSOSAlerts();

    _subscribeToData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _subscribeToData();
      }
    });
  }

  void _subscribeToData() {
    if (user == null) {
      setState(() {
        _loading = false;
        _error = "User not logged in.";
      });
      return;
    }

    _childrenSubscription?.cancel();
    _childrenSubscription = _childrenRef.onValue.listen(
      (event) {
        if (!mounted) return;

        if (event.snapshot.exists) {
          final newChildrenData = Map<String, dynamic>.from(
            event.snapshot.value as Map,
          );

          final mergedChildrenData = <String, dynamic>{};
          newChildrenData.forEach((childId, newChildData) {
            final existingChildData = _childrenData[childId] as Map? ?? {};
            mergedChildrenData[childId] = {
              ...existingChildData,
              ...Map<String, dynamic>.from(newChildData as Map),
            };
          });

          setState(() {
            _childrenData = mergedChildrenData;
            _loading = false;
            print('DEBUG: _childrenData after refresh:');
            mergedChildrenData.forEach((k, v) => print('  $k: $v'));
          });

          mergedChildrenData.forEach((childId, childData) {
            _sosActiveSubscriptions[childId]?.cancel();
            final sosRef = _childrenRef.child(childId).child('isSOSActive');
            _isFirstSOSSync[childId] = _isFirstSOSSync[childId] ?? true;
            _sosActiveSubscriptions[childId] = sosRef.onValue.listen((
              sosEvent,
            ) {
              if (!mounted) return;
              final value = sosEvent.snapshot.value == true;
              print(
                'DEBUG: isSOSActive for $childId changed to $value (lastValue=${_lastSOSValue[childId]})',
              );
              if (_isFirstSOSSync[childId] == true) {
                _lastSOSValue[childId] = value;
                _isFirstSOSSync[childId] = false;
                return;
              }
              if (value == false && _lastSOSValue[childId] == true) {
                _isSOSAlertShowing[childId] = false;
              }
              if (value == true && _lastSOSValue[childId] != true) {
                print('DEBUG: Triggering SOS notification for $childId');
                _handleSOSAlert(childId);
              }
              _lastSOSValue[childId] = value;
            });

            _safeSubscriptions[childId]?.cancel();
            final safeRef = _childrenRef.child(childId).child('safe');
            _lastSafeValue[childId] = _lastSafeValue[childId] ?? true;
            _safeSubscriptions[childId] = safeRef.onValue.listen((safeEvent) {
              if (!mounted) return;

              // Skip notification if watch is being removed
              if (_isRemovingWatch) {
                return;
              }

              final value = safeEvent.snapshot.value == true;
              if (_lastSafeValue[childId] == true && value == false) {
                // Only show notification if watch is still connected
                if (_childrenData[childId]?['isConnected'] == true) {
                  print(
                    'DEBUG: Zone Alert Triggered for $childId from HomeScreen',
                  );
                  showSystemNotificationWithAutoCancel(
                    notificationId: 1002, // Fixed ID for safe zone exit
                    title: 'Out of Safe Zone',
                    body: '${childData['name']} has left the safe zone.',
                  );
                  _showNotification(
                    'Out of Safe Zone',
                    '${childData['name']} has left the safe zone.',
                    isAlert: true,
                    childId: childId,
                  );
                }
              }
              _lastSafeValue[childId] = value;
            });
          });

          _updateWatchSubscriptions(mergedChildrenData);
        } else {
          _clearAllSubscriptions();
          setState(() {
            _childrenData = {};
            _loading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = "Failed to load child data: $error";
            _loading = false;
          });
        }
      },
    );
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          Navigator.pushNamed(context, '/map', arguments: details.payload);
        }
      },
    );
  }

  void _initializeSOSAlerts() {
    _childrenData.forEach((childId, childData) {
      _isSOSAlertShowing[childId] = false;
    });

    _watchSubscriptions.forEach((macAddress, subscription) {
      final childId =
          _childrenData.entries
              .firstWhere(
                (entry) => entry.value['macAddress'] == macAddress,
                orElse: () => MapEntry('', {}),
              )
              .key;

      if (childId.isNotEmpty) {
        _isSOSAlertShowing[childId] = false;
      }
    });
  }

  void _updateWatchSubscriptions(Map<String, dynamic> newChildren) {
    if (!mounted) return;

    final currentMacs = _watchSubscriptions.keys.toSet();
    final newMacs =
        newChildren.values
            .where((data) => data['macAddress'] != null)
            .map((data) => data['macAddress'] as String)
            .toSet();

    currentMacs.difference(newMacs).forEach((macAddress) {
      _watchSubscriptions[macAddress]?.cancel();
      _watchSubscriptions.remove(macAddress);
    });

    newMacs.difference(currentMacs).forEach((macAddress) {
      final subscription = _watchesRef.child(macAddress).onValue.listen((
        watchEvent,
      ) async {
        if (!mounted || !watchEvent.snapshot.exists) return;

        final watchData = watchEvent.snapshot.value as Map;

        if (user == null || watchData['userId'] != user!.uid) {
          return;
        }

        int? lastUpdate;
        if (watchData['lastUpdate'] is int) {
          lastUpdate = watchData['lastUpdate'] as int;
        } else if (watchData['location'] != null &&
            watchData['location']['timestamp'] is int) {
          lastUpdate = watchData['location']['timestamp'] as int;
        } else {
          lastUpdate = DateTime.now().millisecondsSinceEpoch;
        }

        if (lastUpdate != null) {
          final timeDiff = DateTime.now().millisecondsSinceEpoch - lastUpdate;
          final isConnected = timeDiff < 30000;

          final childId =
              newChildren.entries
                  .firstWhere(
                    (entry) => entry.value['macAddress'] == macAddress,
                    orElse: () => const MapEntry('', {}),
                  )
                  .key;

          if (childId.isNotEmpty) {
            if (isConnected) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(
                'watch_connected_notified_$childId',
              ); // TEMP: Remove after testing
              final notifKey = 'watch_connected_notified_$childId';
              final alreadyNotified = prefs.getBool(notifKey) ?? false;
              if (!alreadyNotified) {
                print(
                  'DEBUG: Showing watch connected notification for $childId',
                );
                _showNotification(
                  'Watch Connected',
                  '${_childrenData[childId]['name'] ?? 'A watch'} is now connected.',
                  isAlert: false,
                  childId: childId,
                );
                await prefs.setBool(notifKey, true);
              }
            }

            final location = watchData['location'];
            if (location != null) {
              final lat = location['latitude'] ?? location['lat'];
              final lon = location['longitude'] ?? location['lng'];

              final locationData = {
                'latitude': lat,
                'longitude': lon,
                'timestamp': lastUpdate,
              };

              FirebaseDatabase.instance
                  .ref()
                  .child('users/${user!.uid}/children/$childId/location')
                  .update(locationData);

              _childrenData[childId]['location'] = locationData;

              final currentSafeZone = _childrenData[childId]['safeZone'];
              bool shouldSetDefaultSafeZone = false;
              if (currentSafeZone == null) {
                shouldSetDefaultSafeZone = true;
              } else {
                final latVal =
                    currentSafeZone['latitude'] ??
                    currentSafeZone['lat'] ??
                    0.0;
                final lngVal =
                    currentSafeZone['longitude'] ??
                    currentSafeZone['lng'] ??
                    0.0;
                final radiusVal = currentSafeZone['radius'] ?? 0.0;
                if ((latVal == 0.0 && lngVal == 0.0) || radiusVal == 0.0) {
                  shouldSetDefaultSafeZone = true;
                }
              }
              if (shouldSetDefaultSafeZone &&
                  lat != null &&
                  lon != null &&
                  (lat != 0.0 || lon != 0.0)) {
                final defaultSafeZone = {
                  'latitude': lat,
                  'longitude': lon,
                  'radius': 100.0,
                };
                FirebaseDatabase.instance
                    .ref('users/${user!.uid}/children/$childId/safeZone')
                    .set(defaultSafeZone);
                _childrenData[childId]['safeZone'] = defaultSafeZone;
              }

              final childData = _childrenData[childId];
              if (childData != null && childData['safeZone'] != null) {
                final safeZone = childData['safeZone'];
                final centerLat = safeZone['latitude'];
                final centerLon = safeZone['longitude'];
                final radius = safeZone['radius'];

                if (centerLat != null && centerLon != null && radius != null) {
                  final distance = _calculateDistance(
                    lat,
                    lon,
                    centerLat,
                    centerLon,
                  );
                  final isSafe = distance <= (radius as num).toDouble();

                  final wasSafe = childData['safe'] as bool? ?? true;
                  if (wasSafe && !isSafe) {
                    print(
                      'DEBUG: Zone Alert Triggered for $childId | wasSafe=$wasSafe, isSafe=$isSafe, name=${childData['name']}, lat=$lat, lon=$lon, centerLat=$centerLat, centerLon=$centerLon, radius=$radius',
                    );
                    final notificationId = 2000 + childId.hashCode;
                    () async {
                      if (_isRemovingWatch ||
                          (_suppressSafeZoneNotificationsUntil != null &&
                              DateTime.now().isBefore(
                                _suppressSafeZoneNotificationsUntil!,
                              ))) {
                        print(
                          'DEBUG: Skipping system notification due to removal or cooldown',
                        );
                      } else {
                        await flutterLocalNotificationsPlugin.show(
                          notificationId,
                          'Zone Alert',
                          '${childData['name']} has left the safe zone.',
                          NotificationDetails(
                            android: AndroidNotificationDetails(
                              'zone_channel',
                              'Zone Alerts',
                              importance: Importance.max,
                              priority: Priority.high,
                              playSound: true,
                            ),
                          ),
                        );
                        Future.delayed(Duration(seconds: 5), () {
                          flutterLocalNotificationsPlugin.cancel(
                            notificationId,
                          );
                        });
                      }
                      _showNotification(
                        'Zone Alert',
                        '${childData['name']} has left the safe zone.',
                        isAlert: true,
                        childId: childId,
                      );
                    }();
                    _childrenData[childId]['safe'] = isSafe;
                  }
                }
              }

              final safeZone = watchData['safeZone'];
              if (safeZone != null &&
                  (_childrenData[childId]['safeZone'] == null)) {
                FirebaseDatabase.instance
                    .ref()
                    .child('users/${user!.uid}/children/$childId/safeZone')
                    .update(Map<String, dynamic>.from(safeZone as Map));
                _childrenData[childId]['safeZone'] = safeZone;
              }
            }

            setState(() {
              _childrenData[childId]['isConnected'] = isConnected;
              _childrenData[childId]['lastUpdate'] = lastUpdate;
              _childrenData[childId]['isSOSActive'] =
                  watchData['sos'] as bool? ?? false;
            });
            final sosActive = watchData['sos'] as bool? ?? false;
            FirebaseDatabase.instance
                .ref()
                .child('users/${user!.uid}/children/$childId/isSOSActive')
                .set(sosActive);
          }
        }
      });
      _watchSubscriptions[macAddress] = subscription;
    });
  }

  bool _getSOSAlertState(String childName) {
    return _isSOSAlertShowing[childName] ?? false;
  }

  void _handleSOSAlert(String childName) async {
    print('DEBUG: _handleSOSAlert called for $childName');
    await flutterLocalNotificationsPlugin.show(
      1000 + childName.hashCode,
      'SOS Alert',
      'SOS button is active for $childName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_channel2',
          'SOS Alerts 2',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
    _showNotification(
      'SOS Alert',
      'SOS button is active for $childName',
      isAlert: true,
      childId: childName,
    );
    await _childrenRef.child(childName).child('isSOSActive').set(false);
    final isShowing = _getSOSAlertState(childName);

    if (isShowing) return;

    final notificationId = _sosNotificationIds[childName] ?? childName.hashCode;

    _isSOSAlertShowing[childName] = true;

    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      showDialog(
        context: context,
        barrierDismissible: true,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Center(
                child: Text(
                  'WARNING',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 2,
                  ),
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'SOS button ON for child $childName',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      );
      Future.delayed(Duration(seconds: 4), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    _sosNotificationIds[childName] = notificationId;

    _sosAlertTimers[childName]?.cancel();
    _sosAlertTimers[childName] = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) {
      if (!_notificationsEnabled) {
        timer.cancel();
        return;
      }

      final isStillShowing = _getSOSAlertState(childName);

      if (isStillShowing) {
        flutterLocalNotificationsPlugin.show(
          notificationId,
          'SOS Alert',
          'SOS button is still active for $childName',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'sos_channel2',
              'SOS Alerts 2',
              importance: Importance.max,
              priority: Priority.high,
              visibility: NotificationVisibility.public,
            ),
          ),
        );
      } else {
        timer.cancel();
      }
    });

    Timer(const Duration(seconds: 30), () {
      final isStillShowing = _getSOSAlertState(childName);

      if (isStillShowing) {
        _isSOSAlertShowing[childName] = false;
        _sosAlertTimers[childName]?.cancel();
        _sosAlertTimers.remove(childName);
        _sosNotificationIds.remove(childName);

        flutterLocalNotificationsPlugin.cancel(notificationId);
      }
    });
  }

  void _showNotification(
    String title,
    String message, {
    bool isAlert = false,
    bool showSnackbar = true,
    String? childId,
    String? titleAr,
    String? messageAr,
  }) {
    if (_isRemovingWatch) {
      print(
        'DEBUG: Skipping in-app notification because _isRemovingWatch is true',
      );
      return;
    }
    if (mounted) {
      final activity = Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        icon: isAlert ? Icons.warning : Icons.notifications,
        color: isAlert ? Colors.red : Colors.blue,
        title: title,
        subtitle: message,
        time: _formatTime(DateTime.now()),
        isAlert: isAlert,
      );

      setState(() {
        _activities.insert(0, activity);
        _unreadNotifications++;
      });

      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isAlert ? Colors.red : Colors.blue,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Show',
              textColor: Colors.white,
              onPressed: () {
                if (childId != null) {
                  Navigator.pushNamed(context, '/map', arguments: childId);
                }
              },
            ),
          ),
        );
      }

      final notificationId = Random().nextInt(100000);
      flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'general_channel',
            'General Notifications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    }
  }

  void _showSystemNotification({
    required String title,
    required String body,
    required String childId,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _sosNotificationIds[childId] = notificationId;
    });

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: childId,
    );

    Timer(Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _sosNotificationIds.remove(childId);
        });
        flutterLocalNotificationsPlugin.cancel(notificationId);
      }
    });
  }

  void _showNativeSOSNotification(String childId, String childName) async {
    if (!_notificationsEnabled) {
      print(
        'HomeScreen Log: Notifications disabled - skipping SOS notification',
      );
      return;
    }

    print(
      'HomeScreen Log: Inside _showNativeSOSNotification. _notificationsEnabled: $_notificationsEnabled',
    );

    final notificationId = childId.hashCode;
    _sosNotificationIds[childId] = notificationId;

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'sos_channel2',
        'SOS Alerts 2',
        channelDescription: 'Emergency SOS notifications',
        importance: Importance.max,
        priority: Priority.high,
        color: Theme.of(context).colorScheme.error,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        ticker: 'Emergency SOS Alert',
        ongoing: true,
        autoCancel: false,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'SOS Alert',
      '$childName has pressed the SOS button',
      notificationDetails,
    );

    if (!_getSOSAlertState(childName)) {
      _isSOSAlertShowing[childName] = true;
      _sosAlertTimers[childName]?.cancel();
      _sosAlertTimers[childName] = Timer.periodic(const Duration(seconds: 30), (
        timer,
      ) {
        if (!_notificationsEnabled) {
          timer.cancel();
          return;
        }

        if (_sosNotificationIds.containsKey(childId)) {
          flutterLocalNotificationsPlugin.show(
            notificationId,
            'SOS Alert',
            '$childName has pressed the SOS button',
            notificationDetails,
          );
        } else {
          timer.cancel();
        }
      });
    }
  }

  void _dismissNativeSOSNotification(String childId) async {
    final notificationId = _sosNotificationIds[childId];
    if (notificationId != null) {
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      if (mounted) {
        setState(() {
          _sosNotificationIds.remove(childId);
        });
      }
    }
  }

  void _showNotifications() {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Notifications',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      _activities
                          .map(
                            (activity) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.05),
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
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.error
                                            : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    size: 24,
                                  ),
                                  title: Text(
                                    activity.title,
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          activity.isAlert
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.error
                                              : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    activity.subtitle,
                                    style: GoogleFonts.nunito(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  trailing: Text(
                                    activity.time,
                                    style: GoogleFonts.nunito(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
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
                        _activities.clear();
                        _unreadNotifications = 0;
                      });
                    }
                  },
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.nunito(
                      color: Theme.of(context).colorScheme.error,
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
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
      );
    }
  }

  void _showAppNotification(
    String title,
    String message, {
    bool isAlert = false,
  }) {
    if (!_notificationsEnabled) {
      print(
        'HomeScreen Log: Notifications disabled - skipping native notification',
      );
      return;
    }

    print(
      'HomeScreen Log: Showing native notification: $title - $message (Alert: $isAlert)',
    );

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'kids_tracker_channel',
        'Kids Tracker',
        channelDescription: 'Kids Tracker notifications',
        importance: Importance.max,
        priority: Priority.high,
        color:
            isAlert
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
        playSound: true,
        enableVibration: true,
        showWhen: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    flutterLocalNotificationsPlugin.show(
      0,
      title,
      message,
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen Log: build called.');
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
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
                  color: Theme.of(context).colorScheme.primary,
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
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Keep your kids safe',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withOpacity(0.9),
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
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    Text(
                      'Features',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CardTile(
                      icon: Icons.map,
                      color: Theme.of(context).colorScheme.primary,
                      title: 'View Map',
                      subtitle: 'View all children locations',
                      onTap: () => Navigator.pushNamed(context, '/map'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CardTile(
                      icon: Icons.directions_walk,
                      color: Colors.green,
                      title: 'Activity Tracking',
                      subtitle: 'Monitor daily activities and movements',
                      onTap: () {
                        _showComingSoonDialog(context, 'Activity Tracking');
                      },
                    ),
                    const SizedBox(height: 16),
                    CardTile(
                      icon: Icons.calendar_today,
                      color: Colors.pink,
                      title: 'School Schedule',
                      subtitle: 'Integrate with school calendar',
                      onTap: () {
                        _showComingSoonDialog(context, 'School Schedule');
                      },
                    ),
                    const SizedBox(height: 16),
                    CardTile(
                      icon: Icons.phone,
                      color: Colors.teal,
                      title: 'Emergency Contacts',
                      subtitle: 'Quick access to emergency numbers',
                      onTap: () {
                        _showComingSoonDialog(context, 'Emergency Contacts');
                      },
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

  Widget _buildQuickActions() {
    final List<Widget> cards = [];
    final pairedWatches = _childrenData.entries.toList();

    for (var entry in pairedWatches) {
      final watchId = entry.key;
      final watchData = entry.value;
      cards.add(
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: WatchCard(
            key: ValueKey('watch_$watchId'),
            watchId: watchId,
            data: {
              'name': watchData['name'] ?? 'Watch',
              'status':
                  watchData['isConnected'] == true
                      ? 'Connected'
                      : 'Not Connected',
              'lastLocation':
                  watchData['location'] ??
                  {'latitude': 0, 'longitude': 0, 'timestamp': 0},
              'color': watchData['color'],
              'avatar': watchData['avatar'],
              'lastUpdate': watchData['lastUpdate'],
              'safe': watchData['safe'],
            },
            onSettings:
                () => _navigateToWatchSettings(context, watchId: watchId),
            timeFormatter: _formatTime,
          ),
        ),
      );
    }

    int remainingSlots = 2 - pairedWatches.length;
    for (int i = 0; i < remainingSlots; i++) {
      cards.add(
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: _buildConnectWatchCard(pairedWatches.length + i + 1),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: cards),
    );
  }

  Widget _buildConnectWatchCard(int number) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link,
              size: 40,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            SizedBox(height: 12),
            Text(
              'Connect Watch $number',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/pair'),
              icon: Icon(Icons.add_link),
              label: Text('Connect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
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

    if (_isNavigatingToSettings) return;

    setState(() {
      _isNavigatingToSettings = true;
    });

    try {
      final localContext = context;

      Navigator.push(
            localContext,
            MaterialPageRoute(
              builder:
                  (context) => WatchSettingsScreen(
                    watchId: watchId,
                    getWatchData: (id) => _convertToMap(_childrenData[id]),
                    onRemove: () => _removeWatch(watchId),
                  ),
            ),
          )
          .then((result) {
            if (mounted) {
              setState(() {
                _isNavigatingToSettings = false;
              });

              _subscribeToData();

              if (_cachedWatchUpdateData != null) {
                print(
                  'HomeScreen Log: Processing cached data: $_cachedWatchUpdateData',
                );
                if (mounted) {
                  setState(() {
                    _childrenData = {
                      ..._childrenData,
                      ..._cachedWatchUpdateData!,
                    };
                    print(
                      'HomeScreen Log: Applied cached data to watches: $_childrenData',
                    );
                  });
                }
                _cachedWatchUpdateData = null;
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
    if (_isRemovingWatch) return;

    print('DEBUG: _removeWatch called for $watchId');
    setState(() {
      _isRemovingWatch = true;
    });
    ScaffoldMessenger.of(context).clearSnackBars();

    // Cancel any lingering zone notifications for this watch
    final notificationId = 2000 + watchId.hashCode;
    flutterLocalNotificationsPlugin.cancel(notificationId);

    // Suppress safe zone notifications for 2 seconds after removal starts
    _suppressSafeZoneNotificationsUntil = DateTime.now().add(
      Duration(seconds: 2),
    );
    Future.delayed(Duration(seconds: 2), () {
      _suppressSafeZoneNotificationsUntil = null;
    });

    // Cancel all listeners for this watch before removing to prevent notifications
    print('DEBUG: Cancelling listeners for $watchId');
    _safeSubscriptions[watchId]?.cancel();
    _safeSubscriptions.remove(watchId);
    _sosActiveSubscriptions[watchId]?.cancel();
    _sosActiveSubscriptions.remove(watchId);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isRemovingWatch = false);
        return;
      }

      // Remove from Firebase
      final watchRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/children/$watchId',
      );
      print('DEBUG: Removing watch data from Firebase for $watchId');
      watchRef
          .remove()
          .then((_) {
            if (mounted) {
              setState(() {
                _childrenData.remove(watchId);
                _isRemovingWatch = false;
              });
              print(
                'DEBUG: Watch $watchId removed, notification will be shown.',
              );
              _showNotification(
                'Watch Removed',
                'Successfully removed watch.',
                isAlert: false,
              );
            }
          })
          .catchError((error) {
            if (mounted) {
              setState(() {
                _isRemovingWatch = false;
              });
              print('DEBUG: Error removing watch $watchId: $error');
              _showNotification(
                'Error',
                'Failed to remove watch: $error',
                isAlert: true,
              );
            }
          });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isRemovingWatch = false;
        });
      }
    }
  }

  Map<String, dynamic> _convertToMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map(
          (key, value) => MapEntry(key.toString(), _convertToMap(value)),
        ),
      );
    } else if (data is List) {
      return {'list': data.map((item) => _convertToMap(item)).toList()};
    }
    return {'value': data};
  }

  void _cancelSosTimers() {
    print('HomeScreen Log: Cancelling all SOS timers.');
    _sosTimers.forEach((childId, timer) {
      timer?.cancel();
      print('HomeScreen Log: Canceled SOS timer for $childId.');
    });
    _sosTimers.clear();
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
          _notificationsEnabled = snapshot.value as bool? ?? true;
        });
        print(
          'HomeScreen Log: Loaded notificationsEnabled: $_notificationsEnabled',
        );
      } else {
        print(
          'HomeScreen Log: Notification setting not found in Firebase, using default: $_notificationsEnabled',
        );
      }
    } catch (e) {
      print('HomeScreen Log: Error loading notification setting: $e');
    }
  }

  void _subscribeToNotificationSettingChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationSettingsSubscription = FirebaseDatabase.instance
        .ref('users/${user.uid}/settings/notificationsEnabled')
        .onValue
        .listen(
          (event) {
            if (mounted) {
              final value = event.snapshot.value as bool?;
              setState(() {
                _notificationsEnabled = value ?? true;
              });
              print(
                'HomeScreen Log: Real-time update - notificationsEnabled: $_notificationsEnabled',
              );
            }
          },
          onError: (error) {
            print(
              'HomeScreen Log: Error subscribing to notification setting changes: $error',
            );
          },
        );
  }

  void _unsubscribeFromNotificationSettings() {
    _notificationSettingsSubscription?.cancel();
    _notificationSettingsSubscription = null;
  }

  void _showComingSoonDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Coming Soon'),
            content: Text(
              'The $featureName feature is coming soon! We appreciate your patience.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  void _clearAllSubscriptions() {
    _childrenSubscription?.cancel();
    _watchSubscriptions.forEach((_, subscription) => subscription.cancel());
    _watchSubscriptions.clear();
    _sosActiveSubscriptions.forEach((childId, sub) {
      sub?.cancel();
      _isFirstSOSSync.remove(childId);
      _lastSOSValue.remove(childId);
    });
    _sosActiveSubscriptions.clear();
    _safeSubscriptions.forEach((childId, sub) => sub?.cancel());
    _safeSubscriptions.clear();
  }

  @override
  void dispose() {
    _childrenSubscription?.cancel();
    _refreshTimer?.cancel();
    _sosActiveSubscriptions.forEach((childId, sub) => sub?.cancel());
    _sosActiveSubscriptions.clear();
    _safeSubscriptions.forEach((childId, sub) => sub?.cancel());
    _safeSubscriptions.clear();
    super.dispose();
  }

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

  Future<void> showSystemNotificationWithAutoCancel({
    required int notificationId,
    required String title,
    required String body,
  }) async {
    if (_isRemovingWatch ||
        (_suppressSafeZoneNotificationsUntil != null &&
            DateTime.now().isBefore(_suppressSafeZoneNotificationsUntil!))) {
      print('DEBUG: Skipping system notification due to removal or cooldown');
      return;
    }
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'zone_channel',
          'Zone Alerts',
          channelDescription: 'Safe Zone Alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 5), () {
      flutterLocalNotificationsPlugin.cancel(notificationId);
    });
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

class CardTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? shadowColor;
  final Color? trailingIconColor;

  const CardTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.backgroundColor,
    this.shadowColor,
    this.trailingIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color:
                shadowColor ??
                Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(
          title,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color:
              trailingIconColor ??
              Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
        onTap: onTap,
      ),
    );
  }
}

class WatchCard extends StatelessWidget {
  final String watchId;
  final Map? data;
  final VoidCallback onSettings;
  final String Function(DateTime) timeFormatter;

  const WatchCard({
    super.key,
    required this.watchId,
    required this.data,
    required this.onSettings,
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

    final hasLocation =
        data != null &&
        data!['location'] != null &&
        ((data!['location']['latitude'] != null &&
                data!['location']['longitude'] != null) ||
            (data!['location']['lat'] != null &&
                data!['location']['lng'] != null));

    int? lastUpdate;
    if (data?['lastUpdate'] is int) {
      lastUpdate = data?['lastUpdate'] as int;
    } else if (data?['location'] != null &&
        data?['location']['timestamp'] is int) {
      lastUpdate = data?['location']['timestamp'] as int;
    } else {
      lastUpdate = DateTime.now().millisecondsSinceEpoch;
    }

    final isConnected =
        lastUpdate != null &&
        (DateTime.now().millisecondsSinceEpoch - lastUpdate) < 30000;

    Color watchColor =
        isConnected && data!['color'] != null
            ? Color(_hexToColor(data!['color'] as String))
            : Theme.of(context).colorScheme.primary;

    Color avatarBackgroundColor =
        isConnected && data!['color'] != null
            ? watchColor.withOpacity(0.2)
            : Theme.of(context).colorScheme.primary.withOpacity(0.2);

    Color watchIconColor =
        isConnected && data!['color'] != null
            ? watchColor
            : Theme.of(context).colorScheme.primary;

    print(
      'Determined watchColor: $watchColor, avatarBackgroundColor: $avatarBackgroundColor, watchIconColor: $watchIconColor',
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onSettings,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarBackgroundColor,
                child: Icon(Icons.watch, size: 28, color: watchIconColor),
              ),
              const SizedBox(height: 8),
              Text(
                data?['name'] ?? 'Watch',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                isConnected ? 'Connected' : 'Not Connected',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isConnected
                          ? Colors.green.shade600
                          : Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              if (lastUpdate != null) ...[
                const SizedBox(height: 4),
                Text(
                  timeFormatter(
                    DateTime.fromMillisecondsSinceEpoch(lastUpdate),
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
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
