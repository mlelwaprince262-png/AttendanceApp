import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/employee.dart';
import '../services/face_service.dart';
import '../services/firestore_service.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  CameraController? _controller;
  final FaceService _faceService = FaceService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _busy = false;
  String _status = 'Position your face inside the frame';

  @override
  void initState() {
    super.initState();
    _initCamera();
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
    if (mounted) setState(() {});
  }

  Future<void> _captureAndEnroll() async {
    if (_controller == null || !_controller!.value.isInitialized || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Analyzing your face...';
    });

    try {
      // Take a single picture and run it through face detection.
      // Note: for a live camera stream approach, see AttendanceScreen —
      // enrollment uses a still capture since accuracy matters more than
      // speed here.
      final picture = await _controller!.takePicture();
      final inputImage = picture.path;

      final faces = await _faceService.detectFacesFromFilePath(inputImage);

      if (faces.isEmpty) {
        setState(() => _status = 'No face detected. Try again with better lighting.');
        return;
      }
      if (faces.length > 1) {
        setState(() => _status = 'Multiple faces detected. Make sure only you are in frame.');
        return;
      }

      final signature = _faceService.buildSignature(faces.first);
      if (signature == null) {
        setState(() => _status = 'Could not read facial landmarks clearly. Try again.');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final employee = Employee(
        id: user.uid,
        fullName: user.displayName ?? user.email ?? 'Employee',
        email: user.email ?? '',
        department: '',
        faceSignature: signature,
      );
      await _firestoreService.saveEmployee(employee);

      setState(() => _status = 'Enrollment complete!');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _status = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
      appBar: AppBar(title: const Text('Face Enrollment')),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: CameraPreview(_controller!)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_status, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _captureAndEnroll,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Capture my face'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
