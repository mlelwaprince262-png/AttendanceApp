import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AttendanceHomeScreen(),
    );
  }
}

class AttendanceHomeScreen extends StatefulWidget {
  const AttendanceHomeScreen({super.key});

  @override
  State<AttendanceHomeScreen> createState() => _AttendanceHomeScreenState();
}

class _AttendanceHomeScreenState extends State<AttendanceHomeScreen> {
  // Office Coordinates (Example: Replace with your actual office latitude & longitude)
  final double officeLatitude = -6.7924; 
  final double officeLongitude = 39.2083;
  final double allowedRadiusMeters = 50.0; // Allowed distance limit

  bool isLoading = false;
  String statusMessage = 'Please select an action below:';

  // Function to handle Sign In / Sign Out verification
  Future<void> _verifyAndProceed(String actionType) async {
    setState(() {
      isLoading = true;
      statusMessage = 'Checking your location...';
    });

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          isLoading = false;
          statusMessage = 'Location services are disabled. Please turn on GPS.';
        });
        return;
      }

      // 2. Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            isLoading = false;
            statusMessage = 'Location permissions are denied.';
          });
          return;
        }
      }

      // 3. Get current user position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Calculate distance from office using Haversine formula built into Geolocator
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLatitude,
        officeLongitude,
      );

      // 5. Verify if inside geofence boundary
      if (distanceInMeters <= allowedRadiusMeters) {
        setState(() {
          statusMessage = 'Location verified! Opening camera...';
        });

        // 6. Open Camera for verification snapshot
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
        );

        if (photo != null) {
          setState(() {
            isLoading = false;
            statusMessage = '$actionType Successful! Verified at office.';
          });
        } else {
          setState(() {
            isLoading = false;
            statusMessage = 'Camera verification cancelled.';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          statusMessage = 'Access Denied: You are outside the office boundary (${distanceInMeters.toStringAsFixed(1)}m away).';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = 'Error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Attendance'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_user,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _verifyAndProceed('SIGN IN'),
                        icon: const Icon(Icons.login),
                        label: const Text('SIGN IN', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _verifyAndProceed('SIGN OUT'),
                        icon: const Icon(Icons.logout),
                        label: const Text('SIGN OUT', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}