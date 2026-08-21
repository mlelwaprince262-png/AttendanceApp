enum AttendanceType { signIn, signOut }

class AttendanceRecord {
  final String employeeId;
  final String employeeName;
  final AttendanceType type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double faceMatchConfidence;

  AttendanceRecord({
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.faceMatchConfidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'type': type == AttendanceType.signIn ? 'sign_in' : 'sign_out',
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'faceMatchConfidence': faceMatchConfidence,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      employeeId: map['employeeId'],
      employeeName: map['employeeName'],
      type: map['type'] == 'sign_in'
          ? AttendanceType.signIn
          : AttendanceType.signOut,
      timestamp: DateTime.parse(map['timestamp']),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      faceMatchConfidence: (map['faceMatchConfidence'] as num).toDouble(),
    );
  }
}
