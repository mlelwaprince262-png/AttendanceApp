import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../utils/constants.dart';

/// IMPORTANT LIMITATION (read before relying on this in production):
/// Google ML Kit's Face Detection API detects *that* a face is present,
/// plus landmarks (eyes, nose, mouth) and simple attributes (eyes open,
/// smiling). It does NOT do true face *recognition* (i.e. "is this the
/// same person as photo X") out of the box.
///
/// This service builds a lightweight geometric "signature" from landmark
/// positions as a basic stand-in for matching. It's fine for a first
/// version / internal tool, but it is NOT as accurate as a real face
/// embedding model. For production-grade recognition, swap this out for:
///   - A TFLite embedding model (e.g. MobileFaceNet) run on-device, or
///   - A cloud API (AWS Rekognition, Azure Face API, Google Cloud Vision)
/// The rest of the app (geofencing, Firestore writes, UI) stays the same
/// either way — only the inside of `compareFaces` needs to change.
class FaceService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Detects faces in a live camera stream frame. Returns an empty list if
  /// none found. Used by AttendanceScreen for real-time verification.
  Future<List<Face>> detectFaces(CameraImage image, int sensorOrientation) async {
    final inputImage = _inputImageFromCameraImage(image, sensorOrientation);
    if (inputImage == null) return [];
    return _detector.processImage(inputImage);
  }

  /// Detects faces in a still image saved to disk (e.g. from
  /// CameraController.takePicture()). Used by EnrollmentScreen.
  Future<List<Face>> detectFacesFromFilePath(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    return _detector.processImage(inputImage);
  }

  /// Basic liveness check: confirms eyes are open (not a static photo held
  /// up to the camera). Combine with prompting the user to blink for
  /// stronger liveness checks in production.
  bool passesBasicLivenessCheck(Face face) {
    final left = face.leftEyeOpenProbability ?? 0;
    final right = face.rightEyeOpenProbability ?? 0;
    return left > 0.4 && right > 0.4;
  }

  /// Builds a simple geometric signature from face landmarks, normalized
  /// so it's roughly scale-invariant (works at different distances from
  /// the camera).
  List<double>? buildSignature(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

    if (leftEye == null || rightEye == null || nose == null ||
        leftMouth == null || rightMouth == null) {
      return null;
    }

    final eyeDistance = _distance(leftEye.x, leftEye.y, rightEye.x, rightEye.y);
    if (eyeDistance == 0) return null;

    // Normalize every other distance by eye distance so it doesn't matter
    // how close the person is standing to the camera.
    return [
      _distance(leftEye.x, leftEye.y, nose.x, nose.y) / eyeDistance,
      _distance(rightEye.x, rightEye.y, nose.x, nose.y) / eyeDistance,
      _distance(leftMouth.x, leftMouth.y, rightMouth.x, rightMouth.y) / eyeDistance,
      _distance(nose.x, nose.y, leftMouth.x, leftMouth.y) / eyeDistance,
      _distance(nose.x, nose.y, rightMouth.x, rightMouth.y) / eyeDistance,
    ];
  }

  /// Compares a live signature against the enrolled one.
  /// Returns a confidence score from 0 (no match) to 1 (perfect match).
  double compareFaces(List<double> enrolled, List<double> live) {
    if (enrolled.length != live.length) return 0;

    double totalDifference = 0;
    for (int i = 0; i < enrolled.length; i++) {
      totalDifference += (enrolled[i] - live[i]).abs();
    }
    final avgDifference = totalDifference / enrolled.length;

    // Convert difference into a 0-1 confidence score.
    final confidence = (1 - (avgDifference / FaceMatchConfig.maxLandmarkDifference))
        .clamp(0.0, 1.0);
    return confidence;
  }

  bool isMatch(double confidence) => confidence >= 0.6;

  double _distance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, int sensorOrientation) {
    final bytes = _concatenatePlanes(image.planes);
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    final planeData = image.planes.map(
      (plane) => plane.bytesPerRow,
    ).first;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final builder = BytesBuilder();
    for (final plane in planes) {
      builder.add(plane.bytes);
    }
    return builder.toBytes();
  }

  void dispose() {
    _detector.close();
  }
}
