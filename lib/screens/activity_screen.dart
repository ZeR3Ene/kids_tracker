import 'package:flutter/material.dart';
import 'package:kids_tracker/widgets/activity_list.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF2EC4B6),
      ),
      body: const ActivityList(),
    );
  }
}
