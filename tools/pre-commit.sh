#!/usr/bin/env bash
set -euo pipefail

echo "Running Flutter/Dart checks..."
flutter pub get >/dev/null

echo "Checking format..."
dart format --output=none --set-exit-if-changed .

echo "Analyzing..."
flutter analyze

echo "Running tests..."
flutter test --no-pub

echo "All checks passed."

