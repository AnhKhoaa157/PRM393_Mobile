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
`http://192.168.1.10:5000/api`. `--dart-define=API_BASE=...` remains available
and overrides `.env` for CI or a one-off build.

The Flutter SDK available on this machine currently has a stale SDK lock, so its
platform scaffolding could not be generated here. Once the SDK lock is released,
run `flutter create .` once to generate `android/`, `ios/`, `web/`, etc.; it does
not replace `lib/main.dart` or this app configuration.
