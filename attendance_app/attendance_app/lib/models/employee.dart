class Employee {
  final String id;
  final String fullName;
  final String email;
  final String department;
  final String? enrolledPhotoUrl;
  final List<double>? faceSignature; // simplified landmark-based signature

  Employee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.department,
    this.enrolledPhotoUrl,
    this.faceSignature,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'department': department,
      'enrolledPhotoUrl': enrolledPhotoUrl,
      'faceSignature': faceSignature,
    };
  }

  factory Employee.fromMap(String id, Map<String, dynamic> map) {
    return Employee(
      id: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      department: map['department'] ?? '',
      enrolledPhotoUrl: map['enrolledPhotoUrl'],
      faceSignature: map['faceSignature'] != null
          ? List<double>.from(map['faceSignature'])
          : null,
    );
  }
}
