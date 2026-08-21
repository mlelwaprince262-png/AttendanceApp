import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../services/face_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

enum _Stage { checkingLocation, deniedLocation, ready, verifying, success, failed }

class AttendanceScreen extends StatefulWidget {
  final AttendanceType type;
  const AttendanceScreen({super.key, required this.type});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _controller;
  final FaceService _faceService = FaceService();
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();

  _Stage _stage = _Stage.checkingLocation;
  String _message = 'Checking your location...';
  GeofenceResult? _geofenceResult;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    try {
      final result = await _locationService.checkOfficeGeofence();
      _geofenceResult = result;

      if (!result.isInsideOffice) {
        setState(() {
          _stage = _Stage.deniedLocation;
          _message =
              'You must be at the office to ${widget.type == AttendanceType.signIn ? "sign in" : "sign out"}.\n'
              'You are ${result.distanceMeters.toStringAsFixed(0)}m away.';
        });
        return;
      }

      await _initCamera();
      setState(() {
        _stage = _Stage.ready;
        _message = 'Look at the camera to verify your identity';
      });
    } catch (e) {
      setState(() {
        _stage = _Stage.deniedLocation;
        _message = 'Could not verify location: $e';
      });
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  Future<void> _verifyAndLog() async {
    if (_controller == null || _geofenceResult == null) return;

    setState(() {
      _stage = _Stage.verifying;
      _message = 'Verifying your identity...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final employee = await _firestoreService.getEmployee(user.uid);
      if (employee == null || employee.faceSignature == null) {
        setState(() {
          _stage = _Stage.failed;
          _message = 'No enrolled face found. Please enroll your face first.';
        });
        return;
      }

      final picture = await _controller!.takePicture();
      final faces = await _faceService.detectFacesFromFilePath(picture.path);

      if (faces.isEmpty) {
        setState(() {
          _stage = _Stage.failed;
          _message = 'No face detected. Try again with better lighting.';
        });
        return;
      }

      final face = faces.first;

      if (!_faceService.passesBasicLivenessCheck(face)) {
        setState(() {
          _stage = _Stage.failed;
          _message = 'Liveness check failed. Make sure your eyes are open and visible.';
        });
        return;
      }

      final liveSignature = _faceService.buildSignature(face);
      if (liveSignature == null) {
        setState(() {
          _stage = _Stage.failed;
          _message = 'Could not read facial landmarks clearly. Try again.';
        });
        return;
      }

      final confidence = _faceService.compareFaces(
        employee.faceSignature!,
        liveSignature,
      );

      if (!_faceService.isMatch(confidence)) {
        setState(() {
          _stage = _Stage.failed;
          _message =
              'Face did not match enrolled profile (confidence ${(confidence * 100).toStringAsFixed(0)}%). Try again or contact HR.';
        });
        return;
      }

      final record = AttendanceRecord(
        employeeId: employee.id,
        employeeName: employee.fullName,
        type: widget.type,
        timestamp: DateTime.now(),
        latitude: _geofenceResult!.position.latitude,
        longitude: _geofenceResult!.position.longitude,
        faceMatchConfidence: confidence,
      );
      await _firestoreService.logAttendance(record);

      setState(() {
        _stage = _Stage.success;
        _message =
            '${widget.type == AttendanceType.signIn ? "Signed in" : "Signed out"} successfully!';
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _stage = _Stage.failed;
        _message = 'Something went wrong: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.type == AttendanceType.signIn ? 'Sign In' : 'Sign Out',
        ),
      ),
      body: switch (_stage) {
        _Stage.checkingLocation => const Center(child: CircularProgressIndicator()),
        _Stage.deniedLocation => _InfoView(
            icon: Icons.location_off,
            color: Colors.red,
            message: _message,
            onRetry: () {
              setState(() => _stage = _Stage.checkingLocation);
              _checkLocation();
            },
          ),
        _Stage.ready || _Stage.verifying => Column(
            children: [
              Expanded(
                child: _controller != null && _controller!.value.isInitialized
                    ? CameraPreview(_controller!)
                    : const Center(child: CircularProgressIndicator()),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _stage == _Stage.verifying ? null : _verifyAndLog,
                      child: _stage == _Stage.verifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.type == AttendanceType.signIn
                              ? 'Verify & Sign In'
                              : 'Verify & Sign Out'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        _Stage.success => _InfoView(
            icon: Icons.check_circle,
            color: Colors.green,
            message: _message,
          ),
        _Stage.failed => _InfoView(
            icon: Icons.error,
            color: Colors.red,
            message: _message,
            onRetry: () => setState(() {
              _stage = _Stage.ready;
              _message = 'Look at the camera to verify your identity';
            }),
          ),
      },
    );
  }
}

class _InfoView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final VoidCallback? onRetry;

  const _InfoView({
    required this.icon,
    required this.color,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
