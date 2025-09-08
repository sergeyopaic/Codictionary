# Repository Guidelines

This repository is a Flutter/Dart application. Use the guidance below to develop, test, and contribute changes efficiently and consistently.

## Project Structure & Module Organization
- App source in `lib/` (widgets, state, services). Entry point: `lib/main.dart`.
- Tests in `test/` mirroring `lib/` paths (e.g., `lib/foo/bar.dart` -> `test/foo/bar_test.dart`).
- Platform folders: `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`.
- Assets in `assets/` and declared in `pubspec.yaml`. Build artifacts in `build/` (do not commit).

## Build, Test, and Development Commands
- `flutter pub get` — install/update dependencies.
- `flutter analyze` — static analysis using `analysis_options.yaml`.
- `flutter test` — run unit/widget tests.
- `flutter run -d chrome` — run the web app locally (choose a device as needed).
- `flutter build apk` / `flutter build web` — production builds for Android/Web.

## Coding Style & Naming Conventions
- Follow Dart style (2‑space indent, trailing commas where helpful). Run `dart format .`.
- Names: files use `snake_case.dart`; classes use `UpperCamelCase`; members/methods use `lowerCamelCase`.
- Keep widgets small and composable; prefer `const` constructors where possible.
- Lints are configured in `analysis_options.yaml`; fix or justify warnings before submitting.

## Testing Guidelines
- Use `package:test`/`flutter_test`. Place tests under `test/` with `_test.dart` suffix.
- Aim for meaningful coverage on business logic and critical widgets.
- Example: run a single test file: `flutter test test/foo/bar_test.dart`.

## Commit & Pull Request Guidelines
- Commits: present tense, concise scope (e.g., `feat: add search delegate`, `fix: handle null token`).
- PRs: include summary, screenshots for UI changes, and link related issues. Ensure `flutter analyze` and tests pass.
- Avoid large, mixed changes; prefer focused PRs with clear rationale.

## Security & Configuration
- Do not commit secrets; keep environment values in `.env` and reference securely.
- Validate inputs and handle network errors gracefully in services.

## CI & Local Hooks
- CI runs on pushes/PRs via `.github/workflows/ci.yml` (format check, analyze, tests).
- Optional local pre-commit: `tools/pre-commit.sh`. Install with:
  - macOS/Linux: `chmod +x tools/pre-commit.sh && ln -s ../../tools/pre-commit.sh .git/hooks/pre-commit`
  - Windows (Git Bash): `ln -s ../../tools/pre-commit.sh .git/hooks/pre-commit`
  - Or call manually before committing: `bash tools/pre-commit.sh`.
