import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _onQRViewCreated(QRViewController ctrl) async {
    controller = ctrl;
    controller?.scannedDataStream.listen((scanData) async {
      if (scanned) return;
      setState(() {
        scanned = true;
      });
      final watchId =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'child_1';
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/children/$watchId')
            .set({
              'id': scanData.code,
              'name': 'Watch',
              'color': '#2EC4B6',
              'safeZone': null,
            });
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() {
            error = 'Failed to pair: $e';
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
        title: const Text('Pair Device', style: TextStyle(color: Colors.white)),
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
                  'Scan your child\'s smartwatch QR code to pair.',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              if (scanned)
                const Text(
                  'Paired! Returning...',
                  style: TextStyle(fontSize: 18, color: Colors.green),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
