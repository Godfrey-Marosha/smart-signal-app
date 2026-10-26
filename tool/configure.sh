#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
command -v flutter >/dev/null 2>&1 || { echo 'Install Flutter and add it to PATH first.'; exit 1; }
command -v flutterfire >/dev/null 2>&1 || { echo 'Run: dart pub global activate flutterfire_cli'; exit 1; }
flutter pub get
flutterfire configure --project=street-signal-app-8f363 --platforms=android --android-package-name=com.example.street_smart_app
printf '\nEnable Email/Password in Firebase Authentication, then run flutter run.\n'
