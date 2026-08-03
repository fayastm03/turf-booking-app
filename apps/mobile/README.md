# Turf Spot mobile app

## Local development

Start the API and its PostgreSQL/Redis services first. On an Android emulator the
app connects to `http://10.0.2.2:3000`; iOS simulators and web use
`http://localhost:3000` by default. For a physical phone or a remote server,
provide the reachable API address explicitly:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000
```

Use separate emails for player and turf-owner accounts. Owner sign-up creates a
pending application; an administrator must approve it before Owner Login and
the partner dashboard are available.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
