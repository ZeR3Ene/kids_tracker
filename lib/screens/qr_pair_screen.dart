import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  String watchId = 'child_${DateTime.now().millisecondsSinceEpoch}';
  bool isProcessing = false;
  String? processingMessage;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

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
                const Text(
                  'Paired! Returning...',
                  style: TextStyle(fontSize: 18, color: Colors.green),
                ),
              if (isProcessing)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      processingMessage ?? '',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
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
