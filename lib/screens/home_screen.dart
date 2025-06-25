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
<<<<<<< HEAD
import '../widgets/activity_list.dart';

const Color kPrimaryCyan = Color(0xFF2EC4B6);
const Color kAccentCoral = Color(0xFFFF6F61);
const Color kSoftBackground = Color(0xFFF0FDFC);
const Color kCardBackground = Color(0xFFFFFFFF); // Import kCardBackground
=======
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae

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
<<<<<<< HEAD
  late User? user; // Firebase user
  late DatabaseReference _childrenRef; // Reference to children data
  late DatabaseReference _watchesRef; // Reference to watches data
  Timer? _refreshTimer;
  StreamSubscription? _childrenSubscription;
  Map<String, StreamSubscription> _watchSubscriptions = {};
  Map<String, bool?> _isSOSAlertShowing = {}; // Changed to nullable bool
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
  Map<String, bool> _isFirstSOSSync = {}; // تتبع أول تحميل لكل طفل
  Map<String, bool?> _lastSOSValue = {}; // تتبع آخر قيمة isSOSActive لكل طفل

  Map<String, StreamSubscription?> _safeSubscriptions = {};
  Map<String, bool?> _lastSafeValue = {};

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _childrenRef = FirebaseDatabase.instance.ref('users/${user!.uid}/children');
    _watchesRef = FirebaseDatabase.instance.ref('watches');

    // Initialize notifications
    _initializeNotifications();

    // Initialize SOS alerts
    _initializeSOSAlerts();

    // Start listening to data
    _subscribeToData();

    // Add a timer to refresh data periodically
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

          // Merge new data from Firebase with the existing local state to preserve
          // dynamic fields like 'isConnected' and 'lastUpdate' during rebuilds.
          final mergedChildrenData = <String, dynamic>{};
          newChildrenData.forEach((childId, newChildData) {
            final existingChildData = _childrenData[childId] as Map? ?? {};
            mergedChildrenData[childId] = {
              ...existingChildData,
              ...Map<String, dynamic>.from(newChildData as Map),
            };
          });

          // Update children data
          setState(() {
            _childrenData = mergedChildrenData; // Use merged data
            _loading = false;
            print('DEBUG: _childrenData after refresh:');
            mergedChildrenData.forEach((k, v) => print('  $k: $v'));
          });

          // Add SOS listeners for each child
          mergedChildrenData.forEach((childId, childData) {
            _sosActiveSubscriptions[childId]?.cancel();
            final sosRef = _childrenRef.child(childId).child('isSOSActive');
            _isFirstSOSSync[childId] =
                _isFirstSOSSync[childId] ?? true; // فقط إذا لم يكن موجودًا
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
              // إعادة تعيين حالة الإشعار عند إطفاء الزر
              if (value == false && _lastSOSValue[childId] == true) {
                _isSOSAlertShowing[childId] = false;
              }
              if (value == true && _lastSOSValue[childId] != true) {
                print('DEBUG: Triggering SOS notification for $childId');
                _handleSOSAlert(childId);
              }
              _lastSOSValue[childId] = value;
            });

            // إضافة اشتراك على حقل safe لكل طفل
            _safeSubscriptions[childId]?.cancel();
            final safeRef = _childrenRef.child(childId).child('safe');
            _lastSafeValue[childId] = _lastSafeValue[childId] ?? true;
            _safeSubscriptions[childId] = safeRef.onValue.listen((safeEvent) {
              if (!mounted) return;
              final value = safeEvent.snapshot.value == true;
              print(
                'DEBUG: safe for $childId changed to $value (lastSafe=${_lastSafeValue[childId]})',
              );
              // إشعار عند الخروج من المنطقة الآمنة
              if (_lastSafeValue[childId] == true && value == false) {
                print(
                  'DEBUG: Zone Alert Triggered for $childId from HomeScreen',
                );
                final notificationId = 2000 + childId.hashCode;
                showSystemNotificationWithAutoCancel(
                  notificationId: notificationId,
                  title: 'خارج المنطقة الآمنة',
                  body: '${childData['name']} خرج من المنطقة الآمنة.',
                );
                _showNotification(
                  'خارج المنطقة الآمنة',
                  '${childData['name']} خرج من المنطقة الآمنة.',
                  isAlert: true,
                  childId: childId,
                );
              }
              // إشعار عند الدخول للمنطقة الآمنة
              if (_lastSafeValue[childId] == false && value == true) {
                print(
                  'DEBUG: Safe Alert Triggered for $childId from HomeScreen',
                );
                final notificationId = 3000 + childId.hashCode;
                showSystemNotificationWithAutoCancel(
                  notificationId: notificationId,
                  title: 'داخل المنطقة الآمنة',
                  body: '${childData['name']} دخل المنطقة الآمنة.',
                );
                _showNotification(
                  'داخل المنطقة الآمنة',
                  '${childData['name']} دخل المنطقة الآمنة.',
                  isAlert: true,
                  childId: childId,
                );
              }
              _lastSafeValue[childId] = value;
            });
          });

          // Update watch subscriptions
          _updateWatchSubscriptions(mergedChildrenData); // Use merged data
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
    // Initialize all SOS alert states to false
    _childrenData.forEach((childId, childData) {
      _isSOSAlertShowing[childId] = false;
    });

    // Also initialize any existing watches
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

    // Get current MAC addresses from subscriptions
    final currentMacs = _watchSubscriptions.keys.toSet();
    // Get MAC addresses from new children data
    final newMacs =
        newChildren.values
            .where((data) => data['macAddress'] != null)
            .map((data) => data['macAddress'] as String)
            .toSet();

    // Cancel subscriptions for removed watches
    currentMacs.difference(newMacs).forEach((macAddress) {
      _watchSubscriptions[macAddress]?.cancel();
      _watchSubscriptions.remove(macAddress);
    });

    // Add subscriptions for new watches
    newMacs.difference(currentMacs).forEach((macAddress) {
      final subscription = _watchesRef.child(macAddress).onValue.listen((
        watchEvent,
      ) {
        if (!mounted || !watchEvent.snapshot.exists) return;

        final watchData = watchEvent.snapshot.value as Map;

        // Verify that the watch is linked to the current user
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
          final isConnected = timeDiff < 30000; // 30 seconds

          // Find the corresponding child ID
          final childId =
              newChildren.entries
                  .firstWhere(
                    (entry) => entry.value['macAddress'] == macAddress,
                    orElse: () => const MapEntry('', {}),
                  )
                  .key;

          if (childId.isNotEmpty) {
            // Update location from watches node
            final location = watchData['location'];
            if (location != null) {
              final lat = location['latitude'] ?? location['lat'];
              final lon = location['longitude'] ?? location['lng'];

              final locationData = {
                'latitude': lat,
                'longitude': lon,
                'timestamp': lastUpdate,
              };

              // Update location in Firebase children node
              FirebaseDatabase.instance
                  .ref()
                  .child('users/${user!.uid}/children/$childId/location')
                  .update(locationData);

              // Update local state with new location
              _childrenData[childId]['location'] = locationData;

              // --- Auto-set safeZone with the first valid location from the watch ---
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
              // --- END ---

              // Safe Zone Logic
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
                    // إشعار نظامي مع صوت لمدة 5 ثواني عند الخروج من المنطقة الآمنة
                    final notificationId = 2000 + childId.hashCode;
                    () async {
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
                      // إلغاء الإشعار بعد 5 ثواني
                      Future.delayed(Duration(seconds: 5), () {
                        flutterLocalNotificationsPlugin.cancel(notificationId);
                      });
                      // إشعار داخل التطبيق
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

              // NEW: Sync safeZone from watch to child node
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
              // _childrenData[childId]['batteryLevel'] =
              //     watchData['batteryLevel'] as int? ?? 100;
              _childrenData[childId]['isSOSActive'] =
                  watchData['sos'] as bool? ?? false;
            });
            // مزامنة حالة SOS مع مسار الطفل تحت المستخدم
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

  // Helper method to safely get SOS alert state
  bool _getSOSAlertState(String childName) {
    return _isSOSAlertShowing[childName] ?? false;
  }

  void _handleSOSAlert(String childName) async {
    print('DEBUG: _handleSOSAlert called for $childName');
    // إشعار نظامي فوري عند كل SOS
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
    // أضف إشعار SOS إلى قائمة الأنشطة داخل التطبيق
    _showNotification(
      'SOS Alert',
      'SOS button is active for $childName',
      isAlert: true,
      childId: childName,
    );
    // إعادة تعيين isSOSActive إلى false بعد الإشعار
    await _childrenRef.child(childName).child('isSOSActive').set(false);
    // Get the current SOS state
    final isShowing = _getSOSAlertState(childName);

    // If already showing, return
    if (isShowing) return;

    // Get the notification ID for this child
    final notificationId = _sosNotificationIds[childName] ?? childName.hashCode;

    // Update SOS state
    _isSOSAlertShowing[childName] = true;

    // Show a centered red warning dialog inside the app
    if (mounted) {
      // Close any open dialog first
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
      // Auto-dismiss the dialog after 4 seconds
      Future.delayed(Duration(seconds: 4), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    // Store the notification ID
    _sosNotificationIds[childName] = notificationId;

    // Start repeating notification timer
    _sosAlertTimers[childName]?.cancel();
    _sosAlertTimers[childName] = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) {
      if (!_notificationsEnabled) {
        timer.cancel();
        return;
      }

      // Get current SOS state
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

    // Reset SOS status after 30 seconds if not cleared
    Timer(const Duration(seconds: 30), () {
      // Get current SOS state
      final isStillShowing = _getSOSAlertState(childName);

      if (isStillShowing) {
        // Reset SOS state
        _isSOSAlertShowing[childName] = false;
        _sosAlertTimers[childName]?.cancel();
        _sosAlertTimers.remove(childName);
        _sosNotificationIds.remove(childName);

        // Clear the notification
        flutterLocalNotificationsPlugin.cancel(notificationId);
      }
=======
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
  bool _notificationsEnabled = true; // State variable for notification setting
  StreamSubscription?
  _notificationSettingsSubscription; // Subscription for notification setting changes

  void _incrementNotificationCount() {
    setState(() {
      _unreadNotifications++;
    });
  }

  void _resetNotificationCount() {
    setState(() {
      _unreadNotifications = 0;
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
    });
  }

  void _showNotification(
<<<<<<< HEAD
    String title,
    String message, {
    bool isAlert = false,
    bool showSnackbar = true,
    String? childId,
    String? titleAr,
    String? messageAr,
  }) {
    if (mounted) {
      final activity = Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        icon: isAlert ? Icons.warning : Icons.notifications,
        color: isAlert ? Colors.red : Colors.blue,
=======
      String title,
      String message, {
        bool isAlert = false,
        bool showSnackbar = true,
      }) {
    if (mounted) {
      final activity = Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        icon: isAlert ? Icons.warning : Icons.info,
        color:
        isAlert
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
        title: title,
        subtitle: message,
        time: _formatTime(DateTime.now()),
        isAlert: isAlert,
      );

      setState(() {
<<<<<<< HEAD
        _activities.insert(0, activity); // Add to the beginning of the list
        _unreadNotifications++;
      });

      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isAlert ? Colors.red : Colors.blue,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'عرض',
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

      // إشعار نظامي في كل الحالات
      final notificationId = DateTime.now().millisecondsSinceEpoch;
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

    // حفظ ID الإشعار للطفل
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

    // إنشاء مؤقت لإعادة تعيين الإشعار بعد 30 ثانية
    Timer(Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _sosNotificationIds.remove(childId);
        });
        flutterLocalNotificationsPlugin.cancel(notificationId);
      }
    });
=======
        activities.add(activity);
        _unreadNotifications++;
      });

      // Also show a native phone notification
      print(
        'HomeScreen Log: Checking _notificationsEnabled before _showAppNotification (from _showNotification): $_notificationsEnabled',
      );
      if (_notificationsEnabled) {
        _showAppNotification(title, message, isAlert: isAlert);
      }
    }
  }

  void _showZoneAlert(String childId, String childName) {
    if (mounted) {
      print(
        'HomeScreen Log: _showZoneAlert called for $childName (ID: $childId)',
      );
      // Show native notification for zone alert
      print(
        'HomeScreen Log: Checking _notificationsEnabled before _showAppNotification (from _showZoneAlert): $_notificationsEnabled',
      );
      if (_notificationsEnabled) {
        // Conditionally show notification
        _showAppNotification(
          'Zone Alert',
          '$childName is outside safe zone',
          isAlert: true,
        );
      }
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
    _loadNotificationSetting(); // Load notification setting on init
    _subscribeToNotificationSettingChanges(); // Subscribe to changes

    if (user != null) {
      _loadWatches();
    }

    print(
      'HomeScreen Log: Loaded notificationsEnabled: $_notificationsEnabled',
    );
  }

  @override
  void dispose() {
    print('HomeScreen Log: dispose called.');
    _cancelSosTimers(); // Cancel all SOS timers on dispose
    _cancelDatabaseListeners();
    _unsubscribeFromNotificationSettings(); // Unsubscribe from notification settings
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
                        print(
                          'HomeScreen Log: Checking _notificationsEnabled before _showNativeSOSNotification: $_notificationsEnabled',
                        );
                        if (_notificationsEnabled) {
                          // Conditionally show notification
                          _showNativeSOSNotification(childId, childName);
                        }
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
            color: Theme.of(context).colorScheme.onError,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).colorScheme.onError,
              size: 60,
            ),
            SizedBox(height: 16),
            Text(
              '$childName has triggered an SOS and may be unsafe.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
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
            child: Text(
              'OK',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
    );
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
    ); // Log inside the function

    final notificationId = childId.hashCode;
    _sosNotificationIds[childId] = notificationId; // Store notification ID

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
<<<<<<< HEAD
        'sos_channel2',
        'SOS Alerts 2',
=======
        'sos_channel',
        'SOS Alerts',
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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

    // Start repeating notification if it's not already showing
<<<<<<< HEAD
    if (!_getSOSAlertState(childName)) {
      _isSOSAlertShowing[childName] = true;
      _sosAlertTimers[childName]?.cancel();
      _sosAlertTimers[childName] = Timer.periodic(const Duration(seconds: 30), (
        timer,
      ) {
=======
    if (!_isSOSAlertShowing) {
      _isSOSAlertShowing = true;
      _sosAlertTimer?.cancel();
      _sosAlertTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
    final notificationId = _sosNotificationIds[childId];
    if (notificationId != null) {
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      if (mounted) {
        setState(() {
          _sosNotificationIds.remove(childId);
        });
      }
=======
    if (_sosNotificationIds.containsKey(childId)) {
      await flutterLocalNotificationsPlugin.cancel(
        _sosNotificationIds[childId]!,
      );
      print('Native SOS notification dismissed for $childId.');
      _sosNotificationIds.remove(childId);
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
    }
  }

  void _showNotifications() {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
<<<<<<< HEAD
              backgroundColor:
                  Theme.of(context)
                      .colorScheme
                      .surfaceVariant, // Use theme surface variant for dialog background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Notifications',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant, // Text color for dialog title
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
                                  color:
                                      Theme.of(
                                        context,
                                      ).cardColor, // Use theme card color
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(
                                        0.05,
                                      ), // Shadow color from theme
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
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.error, // Use theme error color
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
                      color:
                          Theme.of(
                            context,
                          ).colorScheme.primary, // Use theme primary color
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
=======
          backgroundColor:
          Theme.of(context)
              .colorScheme
              .surfaceVariant, // Use theme surface variant for dialog background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Notifications',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color:
              Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant, // Text color for dialog title
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
                      color:
                      Theme.of(
                        context,
                      ).cardColor, // Use theme card color
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(
                            0.05,
                          ), // Shadow color from theme
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
                    activities.clear();
                    _unreadNotifications = 0;
                  });
                }
              },
              child: Text(
                'Clear All',
                style: GoogleFonts.nunito(
                  color:
                  Theme.of(
                    context,
                  ).colorScheme.error, // Use theme error color
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
                  color:
                  Theme.of(
                    context,
                  ).colorScheme.primary, // Use theme primary color
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
      );
    }
  }

  void _showAppNotification(
<<<<<<< HEAD
    String title,
    String message, {
    bool isAlert = false,
  }) {
=======
      String title,
      String message, {
        bool isAlert = false,
      }) {
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
            isAlert
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
=======
        isAlert
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
      backgroundColor:
<<<<<<< HEAD
          Theme.of(
            context,
          ).colorScheme.background, // Use theme background color
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).colorScheme.primary, // Use theme primary color
=======
      Theme.of(
        context,
      ).colorScheme.background, // Use theme background color
      appBar: AppBar(
        backgroundColor:
        Theme.of(context).colorScheme.primary, // Use theme primary color
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
                  color:
<<<<<<< HEAD
                      Theme.of(
                        context,
                      ).colorScheme.primary, // Use theme primary color
=======
                  Theme.of(
                    context,
                  ).colorScheme.primary, // Use theme primary color
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
                                color: Theme.of(context).colorScheme.onPrimary,
=======
                                color:
                                Theme.of(context)
                                    .colorScheme
                                    .onPrimary, // Text color on primary background
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
                    _buildQuickActions(),
=======
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
                                  key: ValueKey(
                                    'not_connected_${watches.length + index + 1}',
                                  ),
                                  watchId:
                                  'new_watch_${watches.length + index + 1}',
                                  data: {},
                                  onConnect:
                                      () =>
                                      Navigator.pushNamed(context, '/pair'),
                                  onSettings: () {},
                                  timeFormatter: _formatTime,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    await flutterLocalNotificationsPlugin.show(
                      999,
                      'Test Notification',
                      'This is a test notification',
                      const NotificationDetails(
                        android: AndroidNotificationDetails(
                          'test_channel',
                          'Test Channel',
                          importance: Importance.max,
                          priority: Priority.high,
                        ),
                      ),
                    );
                  },
                  child: Text('Test Notification'),
=======
                    if (!loading || watches.isEmpty)
                      ElevatedButton.icon(
                        onPressed: _addExampleWatches,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Example Watches"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          Theme.of(context).colorScheme.primary,
                          foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
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
                      onPressed: _triggerSOSExample,
                      child: const Text('Trigger SOS (Example Watch 1)'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _simulateLinaOutsideZone,
                      child: const Text('Simulate Lina Outside Zone'),
                    ),
                  ],
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildQuickActions() {
    final List<Widget> cards = [];
    final pairedWatches = _childrenData.entries.toList();

    // Add cards for paired watches
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

    // Add "Connect Watch" cards for remaining slots (up to 2 total)
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
=======
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

      print('Simulated $childId safe status set to: $newSafeStatus');
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
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
    BuildContext context, {
    required String watchId,
  }) {
=======
      BuildContext context, {
        required String watchId,
      }) {
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
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
            // Only update state if we're still mounted
            if (mounted) {
              setState(() {
                _isNavigatingToSettings = false;
              });

              // Always refresh from Firebase after returning from settings
              _subscribeToData();

              // (Optional) If you want to keep the cached update logic for rare cases, keep it below
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
=======
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
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
            if (mounted) {
              setState(() {
                _childrenData.remove(watchId);
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
=======
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
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
      return Map<String, dynamic>.from(
        data.map(
          (key, value) => MapEntry(key.toString(), _convertToMap(value)),
        ),
      );
    } else if (data is List) {
      return {'list': data.map((item) => _convertToMap(item)).toList()};
    }
    return {'value': data};
=======
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
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
    if (user == null) return; // User not logged in

    try {
      final snapshot =
<<<<<<< HEAD
          await FirebaseDatabase.instance
              .ref('users/${user.uid}/settings/notificationsEnabled')
              .get();
=======
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/settings/notificationsEnabled')
          .get();
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
      if (snapshot.exists) {
        setState(() {
          _notificationsEnabled =
              snapshot.value as bool? ??
<<<<<<< HEAD
              true; // Default to true if value is null
=======
                  true; // Default to true if value is null
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
      // Optionally show an error to the user
    }
  }

  void _subscribeToNotificationSettingChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // User not logged in

    _notificationSettingsSubscription = FirebaseDatabase.instance
        .ref('users/${user.uid}/settings/notificationsEnabled')
        .onValue
        .listen(
          (event) {
<<<<<<< HEAD
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
=======
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
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
  }

  void _unsubscribeFromNotificationSettings() {
    _notificationSettingsSubscription?.cancel();
    _notificationSettingsSubscription = null;
  }
<<<<<<< HEAD

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
    // ألغِ جميع اشتراكات SOS
    _sosActiveSubscriptions.forEach((childId, sub) {
      sub?.cancel();
      _isFirstSOSSync.remove(childId); // احذف من تتبع أول تحميل
      _lastSOSValue.remove(childId); // احذف آخر قيمة
    });
    _sosActiveSubscriptions.clear();
    // ألغِ جميع اشتراكات safe
    _safeSubscriptions.forEach((childId, sub) => sub?.cancel());
    _safeSubscriptions.clear();
  }

  @override
  void dispose() {
    _childrenSubscription?.cancel();
    _refreshTimer?.cancel();
    // ألغِ جميع اشتراكات SOS عند التخلص من الشاشة
    _sosActiveSubscriptions.forEach((childId, sub) => sub?.cancel());
    _sosActiveSubscriptions.clear();
    // ألغِ جميع اشتراكات safe
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

  // دالة لإظهار إشعار نظامي مع صوت النظام الافتراضي ويختفي بعد 5 ثواني
  Future<void> showSystemNotificationWithAutoCancel({
    required int notificationId,
    required String title,
    required String body,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'zone_channel',
          'Zone Alerts',
          channelDescription: 'تنبيهات المنطقة الآمنة',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true, // صوت النظام الافتراضي
        ),
      ),
    );
    // إلغاء الإشعار بعد 5 ثواني
    Future.delayed(const Duration(seconds: 5), () {
      flutterLocalNotificationsPlugin.cancel(notificationId);
    });
  }
=======
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
      cos(latRad1) * cos(latRad2) * sin(dLon / 2) * sin(dLon / 2);
=======
          cos(latRad1) * cos(latRad2) * sin(dLon / 2) * sin(dLon / 2);
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae

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
<<<<<<< HEAD
                shadowColor ??
=======
            shadowColor ??
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
              trailingIconColor ??
=======
          trailingIconColor ??
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
=======
  final VoidCallback onConnect;
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
  final VoidCallback onSettings;
  final String Function(DateTime) timeFormatter;

  const WatchCard({
    super.key,
    required this.watchId,
    required this.data,
<<<<<<< HEAD
=======
    required this.onConnect,
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD

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
=======
    final isConnected = data != null && data!['location'] != null;
    Color watchColor =
    isConnected && data!['color'] != null
        ? Color(_hexToColor(data!['color'] as String))
        : Theme.of(
      context,
    ).colorScheme.primary; // Fallback to theme primary

    Color avatarBackgroundColor =
    isConnected && data!['color'] != null
        ? watchColor.withOpacity(
      0.2,
    ) // Use watch color with opacity if connected
        : Theme.of(context).colorScheme.primary.withOpacity(
      0.2,
    ); // Use theme primary with opacity if not connected

    Color watchIconColor =
    isConnected && data!['color'] != null
        ? watchColor // Use watch color if connected
        : Theme.of(
      context,
    ).colorScheme.primary; // Use theme primary if not connected
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae

    print(
      'Determined watchColor: $watchColor, avatarBackgroundColor: $avatarBackgroundColor, watchIconColor: $watchIconColor',
    );

<<<<<<< HEAD
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
=======
    final avatar =
    isConnected && data?['avatar'] != null
        ? CircleAvatar(
      backgroundImage: NetworkImage(data?['avatar']),
      radius: 28,
    )
        : CircleAvatar(
      backgroundColor: avatarBackgroundColor,
      radius: 28,
      child: Icon(Icons.watch, color: watchIconColor, size: 32),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Use theme card color
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(
              0.1,
            ), // Adjusted shadow color opacity
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
              color:
              Theme.of(
                context,
              ).colorScheme.onSurface, // Text color on card surface
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (isConnected) ...[
            Text(
              data?['lastSeen'] != null
                  ? 'Last seen: ${timeFormatter(DateTime.fromMillisecondsSinceEpoch(data?['lastSeen']))}'
                  : 'No recent location',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ), // Text color on card surface with opacity
            ),
            Text(
              data?['safe'] == true ? 'Status: Safe' : 'Status: Outside zone',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color:
                data?['safe'] == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                    .colorScheme
                    .secondary, // Use theme primary or secondary color for status
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: watchColor, // Use the determined watch color
                foregroundColor:
                watchColor.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors
                    .white, // Determine text color based on button color luminance
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
                backgroundColor:
                Theme.of(context)
                    .colorScheme
                    .primary, // Use theme primary for connect button
                foregroundColor:
                Theme.of(
                  context,
                ).colorScheme.onPrimary, // Text color on primary button
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
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
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
<<<<<<< HEAD
}
=======
}
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
