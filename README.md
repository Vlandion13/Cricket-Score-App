Flappy Cricket - Flutter Sports Themed Cricket Scorer (Starter)

What this zip contains:
- A minimal Flutter app (lib/main.dart) implementing:
  * Create two teams and add players
  * Start an innings and record ball-by-ball (runs, extras, wicket)
  * Track batsmen and bowlers stats, run rate, required rate
  * Over-wise recording
  * Export a PDF summary using `pdf` + `printing` packages

How to build & get an APK (steps):
1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Unzip this folder or place it under a workspace.
3. From this folder, run:
   flutter pub get
   flutter run   # to test on a connected device or emulator
   flutter build apk --release   # to build release APK (apk located in build/app/outputs/flutter-apk/)

Notes:
- This is a starter project focused on core scoring logic and PDF export. For production polish, you may want to add persistent storage (sqflite / hive), unit tests, and more UI refinements.
- If you want, I can produce a signed debug APK for you to install, but I cannot sign or distribute it from here. I can guide you step-by-step.

Enjoy testing the app — tell me if you want an APK built and I'll provide detailed instructions or remote build options.