import 'package:flutter/material.dart';

class ChildInfoScreen extends StatelessWidget {
  const ChildInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7EE6D9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7EE6D9),
        elevation: 0,
        title: const Text('Child Info', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFF6F61)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ChildInfoCard(
            name: 'Child 1',
            location: 'Lat: 37.42, Lng: -122.08',
            time: '12:34 PM',
            inZone: true,
          ),
          const SizedBox(height: 24),
          _ChildInfoCard(
            name: 'Child 2',
            location: 'Lat: 37.43, Lng: -122.09',
            time: '12:35 PM',
            inZone: false,
          ),
        ],
      ),
    );
  }
}

class _ChildInfoCard extends StatelessWidget {
  final String name;
  final String location;
  final String time;
  final bool inZone;
  const _ChildInfoCard({required this.name, required this.location, required this.time, required this.inZone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: inZone ? Color(0xFF2EC4B6) : Color(0xFFFF6F61)),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: inZone ? const Color(0xFF2EC4B6) : const Color(0xFFFF6F61),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  inZone ? 'In Safe Zone' : 'Out of Zone',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Last Location: $location', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text('Last Update: $time', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
} 