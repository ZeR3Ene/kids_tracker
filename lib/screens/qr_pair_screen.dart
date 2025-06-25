import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
<<<<<<< HEAD
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
=======
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
import '../models/esp32_watch.dart';
import '../screens/map_screen.dart';
import '../screens/home_screen.dart';

class QRPairScreen extends StatefulWidget {
  const QRPairScreen({super.key});

  @override
  State<QRPairScreen> createState() => _QRPairScreenState();
}

class _QRPairScreenState extends State<QRPairScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool scanned = false;
  String? error;
<<<<<<< HEAD
  String? watchId;
  bool isProcessing = false;
  String? processingMessage;
  Position? _currentPosition;
  final _database = FirebaseDatabase.instance.ref();
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            error =
                'Camera permission is required to scan QR codes. Please enable it in settings.';
            isProcessing = false;
            processingMessage = null;
          });
        }
        return;
      }

      // Start QR scanning after permission is granted
      if (mounted) {
        setState(() {
          isProcessing = true;
          processingMessage = 'Initializing camera... Please wait';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Error requesting camera permission: $e';
          isProcessing = false;
          processingMessage = null;
        });
      }
    }
  }

  Future<void> _onQRViewCreated(QRViewController ctrl) async {
    try {
      controller = ctrl;
      print('QR Scanner: Camera controller created');

      // Add a delay to ensure the camera is ready
      await Future.delayed(const Duration(milliseconds: 2000));

      if (mounted) {
        setState(() {
          _cameraInitialized = true;
          isProcessing = false;
          processingMessage = 'Camera ready. Hold QR code in front of camera';
        });
      }

      controller?.scannedDataStream.listen((scanData) async {
        print('QR Scanner: Data received: ${scanData.code}');

        if (scanned || isProcessing) {
          print('QR Scanner: Already processing or scanned, ignoring');
          return;
        }

        setState(() {
          scanned = true;
          isProcessing = true;
          processingMessage = 'Processing QR code...';
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) {
            setState(() {
              error = 'User not authenticated. Please login again.';
              isProcessing = false;
              processingMessage = null;
            });
          }
          return;
        }

        try {
          setState(() {
            processingMessage = 'Validating MAC address...';
          });

          // Validate MAC address format
          final qrData = scanData.code;
          if (qrData == null || qrData.isEmpty) {
            throw Exception('No QR code data found. Please try again.');
          }

          print('QR Scanner: Raw QR data: $qrData');

          // Remove any whitespace and convert to uppercase
          final cleanedQR = qrData.trim().toUpperCase();

          // More flexible MAC address regex
          if (!RegExp(
            r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
          ).hasMatch(cleanedQR)) {
            throw Exception(
              'Invalid MAC address format. Expected format: XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX',
            );
          }

          setState(() {
            processingMessage = 'Checking for existing watch...';
          });

          // Check if watch already exists
          final existingWatch =
              await FirebaseDatabase.instance
                  .ref('users/${user.uid}/children')
                  .orderByChild('macAddress')
                  .equalTo(cleanedQR)
                  .once();

          if (existingWatch.snapshot.exists) {
            throw Exception('This watch is already paired with your account.');
          }

          setState(() {
            processingMessage = 'Registering watch...';
          });

          // Get existing watches count
          final childrenRef = FirebaseDatabase.instance.ref(
            'users/${user.uid}/children',
          );
          final childrenSnapshot = await childrenRef.get();
          final childrenCount =
              childrenSnapshot.exists
                  ? (childrenSnapshot.value as Map).length
                  : 0;

          // Generate watch ID based on count
          watchId = 'child_${childrenCount + 1}';

          // Use a default location (0,0) which will be updated by the watch's first real location
          final position = Position(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
            isMocked: false,
          );

          // Create watch data - UNIFIED AND CLEANED
          final watchData = {
            'macAddress': cleanedQR,
            'name': 'Child ${childrenCount + 1}',
            'pairedAt': DateTime.now().millisecondsSinceEpoch,
            'location': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
            'safeZone': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'radius': 100.0,
            },
            'safe': true, // Assume safe initially
          };

          // Set the initial child data in a single operation
          await FirebaseDatabase.instance
              .ref('users/${user.uid}/children/${watchId}')
              .set(watchData);

          // Also update watches node with MAC address and userId
          await FirebaseDatabase.instance.ref('watches/${cleanedQR}').update({
            'userId': user.uid,
            'watchId': watchId,
          });

          setState(() {
            processingMessage = 'Successfully paired!';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Watch paired successfully!')),
            );

            // Add a small delay before navigating back
            await Future.delayed(const Duration(milliseconds: 1000));

            if (mounted) {
              // Navigate to home screen and trigger refresh
              Navigator.of(context).pushReplacementNamed('/home');
            }
          }
        } catch (e) {
          print('QR Scanner: Error processing QR code: $e');
          if (mounted) {
            setState(() {
              error = 'Failed to pair: ${e.toString()}';
              isProcessing = false;
              processingMessage = null;
              scanned = false; // Reset to allow retry
            });
          }
        }
      });

      // Add a timer to check if scanning is working
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && !scanned && !isProcessing && _cameraInitialized) {
          setState(() {
            error =
                'No QR code detected. Please make sure the QR code is clearly visible and try again.';
            isProcessing = false;
            processingMessage = null;
          });
        }
      });
    } catch (e) {
      print('QR Scanner: Camera initialization error: $e');
      if (mounted) {
        setState(() {
          error = 'Error initializing camera: $e';
          isProcessing = false;
          processingMessage = null;
        });
      }
    }
  }
=======
  String watchId = 'child_${DateTime.now().millisecondsSinceEpoch}';
  bool isProcessing = false;
  String? processingMessage;
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

<<<<<<< HEAD
  void _retryScanning() {
    setState(() {
      error = null;
      scanned = false;
      isProcessing = false;
      processingMessage = null;
    });

    // Restart camera
    if (controller != null) {
      controller!.resumeCamera();
    }
=======
  Future<void> _onQRViewCreated(QRViewController ctrl) async {
    controller = ctrl;
    controller?.scannedDataStream.listen((scanData) async {
      if (scanned || isProcessing) return;

      setState(() {
        scanned = true;
        isProcessing = true;
        processingMessage = 'Scanning QR code...';
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            error = 'User not authenticated';
            isProcessing = false;
            processingMessage = null;
          });
        }
        return;
      }

      try {
        setState(() {
          processingMessage = 'Validating MAC address...';
        });

        // Validate MAC address format
        final qrData = scanData.code;
        if (qrData == null) {
          throw Exception('No QR code data found');
        }

        if (!RegExp(
          r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
        ).hasMatch(qrData)) {
          throw Exception(
            'Invalid MAC address format. Format should be XX:XX:XX:XX:XX:XX',
          );
        }

        setState(() {
          processingMessage = 'Checking for existing watch...';
        });

        // Check if watch already exists
        final existingWatch =
            await FirebaseDatabase.instance
                .ref('users/${user.uid}/children')
                .orderByChild('macAddress')
                .equalTo(qrData)
                .once();

        if (existingWatch.snapshot.exists) {
          throw Exception('This watch is already paired');
        }

        setState(() {
          processingMessage = 'Registering watch...';
        });

        // Create watch data with comprehensive fields
        final watchData = {
          'id': watchId,
          'name': 'Child Watch',
          'color': '#2EC4B6',
          'safeZone': {'radius': 100.0, 'latitude': 0.0, 'longitude': 0.0},
          'isConnected': false,
          'batteryLevel': 100,
          'isSOSActive': false,
          'status': 'offline',
          'macAddress': qrData,
          'lastUpdate': DateTime.now().toIso8601String(),
          'lastLocation': {
            'latitude': 0.0,
            'longitude': 0.0,
            'timestamp': DateTime.now().toIso8601String(),
            'accuracy': 0.0,
          },
          'safe': true,
          'settings': {
            'vibration': true,
            'sound': true,
            'led': true,
            'updateInterval': 30, // seconds
          },
          'metadata': {
            'model': 'ESP32',
            'firmwareVersion': '1.0',
            'lastSync': DateTime.now().toIso8601String(),
          },
        };

        // Write to Firebase
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/children/$watchId')
            .set(watchData);

        setState(() {
          processingMessage = 'Setting up watch updates...';
        });

        // Subscribe to watch updates
        final watchRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/children/$watchId',
        );

        String? previousStatus;
        bool safeZoneSet = false;
        watchRef.onValue.listen((event) async {
          if (mounted) {
            final data = event.snapshot.value as Map;
            final currentStatus = data['status'] as String?;
            final safeZone = data['safeZone'] as Map?;
            final lastLocation = data['lastLocation'] as Map?;
            final lat = lastLocation?['latitude'] ?? 0.0;
            final lng = lastLocation?['longitude'] ?? 0.0;
            final safeLat = safeZone?['latitude'] ?? 0.0;
            final safeLng = safeZone?['longitude'] ?? 0.0;
            // Only set safeZone if:
            // - status just transitioned to online
            // - safeZone is still default (0,0)
            // - lastLocation is a real coordinate (not 0,0)
            if (currentStatus == 'online' &&
                previousStatus != 'online' &&
                !safeZoneSet) {
              if ((lat != 0.0 || lng != 0.0) &&
                  (safeLat == 0.0 && safeLng == 0.0)) {
                await watchRef.update({
                  'safeZone': {
                    'radius': safeZone?['radius'] ?? 100.0,
                    'latitude': lat,
                    'longitude': lng,
                  },
                });
                safeZoneSet = true;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Safe area set to watch location!'),
                    ),
                  );
                }
              }
            }
            previousStatus = currentStatus;

            // Update map screen if it's open
            if (Navigator.of(context).canPop()) {
              final currentRoute = ModalRoute.of(context)?.settings.name;
              if (currentRoute == '/map') {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/map');
              }
            }
          }
        });

        setState(() {
          processingMessage = 'Successfully paired!';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Watch paired successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            error = 'Failed to pair: ${e.toString()}';
            isProcessing = false;
            processingMessage = null;
          });
        }
      }
    });
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7EE6D9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7EE6D9),
        elevation: 0,
        title: const Text(
          'Pair Child Watch',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
<<<<<<< HEAD
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.red,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 200,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _retryScanning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!scanned && error == null)
                Text(
                  'Scan your child watch QR code to pair.\nQR code should contain MAC address (e.g., 12:34:56:78:90:AB)',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              if (scanned && !isProcessing && error == null)
=======
                child: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
              ),
              const SizedBox(height: 32),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (!scanned)
                const Text(
                  'Scan your child watch QR code to pair.\nQR code should contain MAC address (e.g., 12:34:56:78:90:AB)',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              if (scanned && !isProcessing)
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
                const Text(
                  'Paired! Returning...',
                  style: TextStyle(fontSize: 18, color: Colors.green),
                ),
              if (isProcessing)
                Column(
                  children: [
<<<<<<< HEAD
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
=======
                    const CircularProgressIndicator(),
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
                    const SizedBox(height: 16),
                    Text(
                      processingMessage ?? '',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
<<<<<<< HEAD
                      textAlign: TextAlign.center,
=======
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
