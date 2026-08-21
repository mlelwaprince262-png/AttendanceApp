# Employee Attendance App

A Flutter app for face-verified, location-restricted employee sign-in/sign-out,
storing records in Firebase Firestore.

## What's included

- Email/password login (Firebase Auth)
- Face enrollment (capture a reference photo once)
- Geofenced sign-in/out: only works within a set radius of the office
- Live face verification before logging attendance
- Attendance history view
- All records saved to Firestore

## ⚠️ Before you start: read this

The face verification here uses **Google ML Kit's face detection + a basic
geometric landmark comparison**, not a true face-recognition embedding
model. It's good enough for a first version / internal tool, but it is
**not as accurate as commercial face recognition** (it can be fooled more
easily and may have more false rejects/accepts). See the comment at the
top of `lib/services/face_service.dart` for how to upgrade to a proper
model (TFLite embedding model or a cloud API) later without changing the
rest of the app.

Also — **you are collecting biometric data from employees.** Before
deploying this for real:
- Get explicit, informed consent from employees (usually in writing)
- Check what your local data protection law requires (e.g. GDPR in the
  EU has specific rules for biometric data)
- Consider a fallback (PIN/manual approval) for when face matching fails
- Add face image data to your Firestore Storage Rules so only the
  employee and admins can read the photo, not other employees

## Step-by-step setup

### 1. Install prerequisites
- Flutter SDK (already installed, per your setup)
- A Firebase account: https://console.firebase.google.com

### 2. Create a Firebase project
1. Go to the Firebase console → "Add project"
2. Enable **Authentication** → Email/Password sign-in method
3. Enable **Firestore Database** (start in production mode)
4. Enable **Storage** (only needed if you later store enrollment photos)

### 3. Connect this project to Firebase
From the root of this project folder, run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Follow the prompts, select your Firebase project, and pick Android/iOS.
This overwrites `lib/firebase_options.dart` with your real project's keys.

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Add required permissions

**Android** — edit `android/app/src/main/AndroidManifest.xml`, inside the
`<manifest>` tag (before `<application>`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Also set `minSdkVersion 21` or higher in `android/app/build.gradle`.

**iOS** — edit `ios/Runner/Info.plist`, add:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to verify your identity for attendance</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to confirm you're at the office</string>
```

### 6. Set your office coordinates
Edit `lib/utils/constants.dart`:

```dart
static const double officeLatitude = YOUR_LATITUDE;
static const double officeLongitude = YOUR_LONGITUDE;
static const double allowedRadiusMeters = 100; // adjust as needed
```

Find coordinates by right-clicking your office on Google Maps.

### 7. Set Firestore security rules
In the Firebase console → Firestore → Rules, use something like:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /employees/{employeeId} {
      allow read, write: if request.auth != null && request.auth.uid == employeeId;
    }
    match /attendance/{recordId} {
      allow create: if request.auth != null
                     && request.auth.uid == request.resource.data.employeeId;
      allow read: if request.auth != null
                  && request.auth.uid == resource.data.employeeId;
    }
  }
}
```

(For an admin dashboard to read everyone's records, you'll want a separate
admin role/claim — ask me and I can help you build that next.)

### 8. Create employee accounts
For now, create accounts manually in Firebase console → Authentication →
Add user. Later you can build an admin screen to do this from the app.

### 9. Run it

```bash
flutter run
```

## How employees use it

1. Log in with their work email
2. First time: tap "Enroll / update my face" and capture a reference photo
3. Each day: open the app at the office, tap Sign In / Sign Out, look at
   the camera — done

## What to build next (suggested order)
1. Admin web dashboard to view all employees' attendance (I can help — this
   would likely be a separate small web app or a Firebase-hosted page)
2. Push notifications reminding employees to sign out
3. Offline queue (log locally if no internet, sync when back online)
4. Stronger liveness detection (ask user to blink or turn head)
5. Export attendance to CSV/Excel for payroll

Just let me know which of these you want to tackle next, and I'll build it out.
