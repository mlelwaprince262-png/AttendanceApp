import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import '../models/attendance_record.dart';
import '../utils/constants.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ---------- Employees ----------

  Future<void> saveEmployee(Employee employee) async {
    await _db
        .collection(FirestoreCollections.employees)
        .doc(employee.id)
        .set(employee.toMap());
  }

  Future<Employee?> getEmployee(String employeeId) async {
    final doc = await _db
        .collection(FirestoreCollections.employees)
        .doc(employeeId)
        .get();
    if (!doc.exists) return null;
    return Employee.fromMap(doc.id, doc.data()!);
  }

  Stream<List<Employee>> watchEmployees() {
    return _db.collection(FirestoreCollections.employees).snapshots().map(
          (snap) => snap.docs
              .map((d) => Employee.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ---------- Attendance ----------

  Future<void> logAttendance(AttendanceRecord record) async {
    await _db.collection(FirestoreCollections.attendance).add(record.toMap());
  }

  /// Returns today's most recent attendance entry for an employee, so the
  /// app knows whether to show "Sign In" or "Sign Out" next.
  Future<AttendanceRecord?> getLastRecordToday(String employeeId) async {
    final startOfDay = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );

    final snap = await _db
        .collection(FirestoreCollections.attendance)
        .where('employeeId', isEqualTo: employeeId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return AttendanceRecord.fromMap(snap.docs.first.data());
  }

  Stream<List<AttendanceRecord>> watchAttendanceHistory(String employeeId) {
    return _db
        .collection(FirestoreCollections.attendance)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList());
  }
}
