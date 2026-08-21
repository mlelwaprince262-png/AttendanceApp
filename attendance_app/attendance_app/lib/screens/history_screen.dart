import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_record.dart';
import '../services/firestore_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();
    final dateFormat = DateFormat('EEE, MMM d • h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance History')),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<List<AttendanceRecord>>(
              stream: firestoreService.watchAttendanceHistory(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = snapshot.data!;
                if (records.isEmpty) {
                  return const Center(child: Text('No attendance records yet'));
                }
                return ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final isSignIn = record.type == AttendanceType.signIn;
                    return ListTile(
                      leading: Icon(
                        isSignIn ? Icons.login : Icons.logout,
                        color: isSignIn ? Colors.green : Colors.orange,
                      ),
                      title: Text(isSignIn ? 'Signed In' : 'Signed Out'),
                      subtitle: Text(dateFormat.format(record.timestamp)),
                      trailing: Text(
                        '${(record.faceMatchConfidence * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
