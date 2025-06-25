import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../screens/home_screen.dart'; // لاستيراد كلاس Activity

class ActivityList extends StatelessWidget {
  final List<Activity> activities;
  const ActivityList({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Center(child: Text('لا يوجد إشعارات بعد.'));
    }
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ListTile(
          leading: Icon(activity.icon, color: activity.color),
          title: Text(activity.title),
          subtitle: Text(activity.subtitle),
          trailing: Text(activity.time),
        );
      },
    );
=======

class ActivityList extends StatelessWidget {
  const ActivityList({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Activity List Content'));
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
  }
}
