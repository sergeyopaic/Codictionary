# Repository Guidelines

## Project Structure & Modules
- Root docs: `ARCHITECTURE.md`, `README.md`, roadmaps.
- App code lives in `app/`.
  - Entry points: `lib/main.dart`, `lib/main_development.dart`,.
  - Layers (Clean Architecture):
    - `lib/presentation/` (UI, GoRouter routes, ViewModels)
    - `lib/domain/` (models, repositories, use-cases, exceptions)
    - `lib/data/` (data sources/services, mappers, repository implementations; prefer returning domain models and map at the edges)
  - Composition/DI: `lib/composition/providers/*`.
  - Tests are simplified in `app/test/`:
    - `ui/` (user flows), `usecases/` (domain), `fakes/`, `helpers/`.

## Build, Test, and Dev Commands
- From repo root: `cd app`
- Run app (dev): `flutter run -t lib/main_development.dart`
- Analyze: `flutter analyze`
- Format: `dart format .`
- Tests: `flutter test`
- Dependencies are managed by maintainers/CI; do not run any pub commands locally.

## Coding Style & Naming
- Dart/Flutter, 2‑space indent, trailing commas in Flutter widget trees.
- Files: `lower_snake_case.dart`; Classes/Enums: `UpperCamelCase`; members: `lowerCamelCase`.
- Providers: group under `composition/providers/*.dart`; prefer small, focused providers.
- Linting via `flutter_lints`. Fix all analyzer warnings before PR.

## Testing Guidelines
- Strategy (see ARCHITECTURE.md §8): prioritize real UI flows and domain rules; skip low‑value glue tests.
- Structure: `test/ui/` for flows, `test/usecases/` for domain, shared `test/fakes/` and `test/helpers/`.
- Examples: `test/ui/counter_list_flow_test.dart`, `test/usecases/create_counter_test.dart`.
- Name tests `*_test.dart`; keep fast and deterministic with in‑memory fakes.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `type(scope): summary`.
  - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `style`.
  - Breaking changes: `feat!: summary` and/or footer `BREAKING CHANGE: ...`.
  - Examples: `feat(counter): add multi-increment`, `fix(router): correct initialLocation`.
- Each PR includes: clear description, linked issue, screenshots/GIFs for UI, test plan, and notes on migrations/codegen if needed.
- CI hygiene: run analyze, format, and tests before pushing.

## Architecture Notes
- Strict boundaries: `presentation → domain → data`; UI must not import `data` directly.
- Presentation calls only domain use-cases; never access repositories directly from UI/ViewModels.
- Data layer avoids persistence-specific leakage. Use adapters/gateways and keep persistence pluggable.
- Where possible, repositories and data services work directly with domain models; use DTOs only at external boundaries and map to domain immediately.

## Restrictions
- Never edit `app/pubspec.yaml` or `app/pubspec.lock`.
- Never run `flutter pub …` (or `dart pub …`) locally. If dependencies seem out of sync, open an issue.