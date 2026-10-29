#!/usr/bin/env bash
# The same checks as CI. Uses --no-pub: dependencies are managed by the
# maintainers and must not be fetched or changed locally.
set -euo pipefail

echo "Checking format..."
dart format --output=none --set-exit-if-changed .

echo "Analyzing..."
flutter analyze --no-pub

echo "Running tests..."
flutter test --no-pub

echo "Checking for secrets..."
dart tools/check_no_secrets.dart --tracked

echo "All checks passed."
