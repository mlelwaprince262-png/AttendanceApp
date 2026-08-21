/// Central place for configuration you need to edit before running the app.
class OfficeConfig {
  // TODO: Replace with your real office coordinates.
  // Find these by right-clicking your office location on Google Maps.
  static const double officeLatitude = 6.7924; // placeholder (Dar es Salaam)
  static const double officeLongitude = 39.2083; // placeholder

  // Radius, in meters, within which sign-in/out is allowed.
  static const double allowedRadiusMeters = 100;
}

/// Firestore collection names, kept in one place so they're easy to change.
class FirestoreCollections {
  static const employees = 'employees';
  static const attendance = 'attendance';
}

/// Simple face-match tolerance. Lower = stricter matching.
/// This is used by FaceService when comparing landmark geometry
/// between the enrolled face and the live capture.
class FaceMatchConfig {
  static const double maxLandmarkDifference = 0.18;
  static const double minFaceDetectionConfidence = 0.7;
}
