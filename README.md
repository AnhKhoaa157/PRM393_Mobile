# PRM393 Mobile

Flutter migration of `ParkingManagement_Mobile`.

## Run

The app targets the existing backend API. Copy `.env.example` to `.env` and set
`API_BASE`. An Android emulator normally reaches a local backend through
`10.0.2.2`:

```powershell
flutter pub get
flutter run
```

Use a LAN address instead for a physical device, for example
`http://192.168.1.10:5000/api`; do not use `localhost` on a physical device.
When running Flutter Web locally, the same emulator address is automatically
mapped to `localhost`.
The Android manifest explicitly allows local HTTP development traffic. Deploy
the backend behind HTTPS before publishing a production build.

The backend currently chooses the next available port when `PORT=5000` is
occupied. Check its startup log and keep `API_BASE` on that exact port; the
mobile app cannot discover a port chosen dynamically.

The Flutter SDK available on this machine currently has a stale SDK lock, so its
platform scaffolding could not be generated here. Once the SDK lock is released,
run `flutter create .` once to generate `android/`, `ios/`, `web/`, etc.; it does
not replace `lib/main.dart` or this app configuration.
