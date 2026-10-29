# Repository Guidelines

## Project Structure & Modules
- Root docs: `README.md`, `ARCHITECTURE.MD`, `docs/RELEASE.md` (platform
  matrix, release checklist), `docs/TEST_MATRIX.md` (scenario → tests).
- The Flutter project is the repository root (there is no `app/` folder).
  - Entry point: `lib/main.dart` (the only one).
  - Layers (Clean Architecture, see ARCHITECTURE.MD):
    - `lib/presentation/` (UI, ViewModels, `l10n/` texts, `theme/`)
    - `lib/domain/` (entities, repository and service interfaces, use cases, exceptions)
    - `lib/data/` (storage, remote clients, backup, records, repository implementations; return domain models and map at the edges)
  - Composition/DI: `lib/composition/` (`app_config.dart`, `app_dependencies.dart`). No service locator; the UI gets use cases from `AppScope`.
  - Tests in `test/`: `ui/` (user flows), `usecases/` (domain rules), `fakes/`, `helpers/`.
  - Live API checks in `smoke/` (not run by `flutter test`).
  - Scripts in `tools/` (`pre-commit.sh`, `check_no_secrets.dart`).

## Build, Test, and Dev Commands
- Run from the repository root.
- `.env` must exist (it is a bundled asset); empty keys mean local mode:
  `OPENAI_API_KEY=` and `DEEPL_API_KEY=`.
- Run app: `flutter run` (add `-d windows`, `-d chrome`, …).
- Analyze: `flutter analyze --no-pub`
- Format: `dart format .` (CI checks `dart format --output=none --set-exit-if-changed .`)
- Tests: `flutter test --no-pub`
- Secrets: `dart tools/check_no_secrets.dart --tracked` (and on a build folder before release).
- All checks: `tools/pre-commit.sh`.
- Use `--no-pub`: without it `flutter analyze`/`test` run pub get implicitly.
- Dependencies are managed by maintainers/CI; do not run any pub commands locally.

## Coding Style & Naming
- Dart/Flutter, 2‑space indent, trailing commas in Flutter widget trees.
- Files: `lower_snake_case.dart`; Classes/Enums: `UpperCamelCase`; members: `lowerCamelCase`.
- UI texts go into `lib/presentation/l10n/` (`AppStrings` with `EnStrings` and `RuStrings`); never hard-code a visible string in a widget.
- Linting via `flutter_lints`. Fix all analyzer warnings before PR.

## Testing Guidelines
- Strategy (see ARCHITECTURE.MD §8): prioritize real UI flows and domain rules; skip low‑value glue tests.
- Build the app graph with `testUseCases(...)` from `test/helpers/test_dependencies.dart`: real use cases and repositories over in-memory storage (`test/fakes/`), fake AI/translation services.
- Examples: `test/ui/core_journey_test.dart`, `test/usecases/word_order_test.dart`.
- Name tests `*_test.dart`; keep fast and deterministic with in‑memory fakes. Tests must never touch the real user data folder or call paid APIs.
- When adding a critical scenario, add it to `docs/TEST_MATRIX.md`.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `type(scope): summary`.
  - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `style`.
  - Breaking changes: `feat!: summary` and/or footer `BREAKING CHANGE: ...`.
  - Examples: `feat(vocabs): real collections with stable ids`, `fix(storage): keep damaged data aside`.
- Each PR includes: clear description, linked issue, screenshots/GIFs for UI, test plan, and notes on migrations/codegen if needed.
- CI hygiene: run analyze, format, and tests before pushing.

## Architecture Notes
- Strict boundaries: `presentation → domain ← data`; only `composition` imports `data`. UI must not import `data` directly (checked by `test/architecture_test.dart`).
- Presentation calls only domain use-cases; never access repositories directly from UI/ViewModels.
- Data layer avoids persistence-specific leakage. Use adapters/gateways and keep persistence pluggable.
- Where possible, repositories and data services work directly with domain models; use DTOs only at external boundaries and map to domain immediately.

## Secrets
- Never commit `.env`, keys, `android/key.properties` or keystores, and never print key values in logs or output.
- CI builds with empty keys and fails if a key-like value is found in the repo or the web build.

## Restrictions
- Never edit `pubspec.yaml` or `pubspec.lock` (repository root).
- Never run `flutter pub …` (or `dart pub …`) locally. If dependencies seem out of sync, open an issue.
