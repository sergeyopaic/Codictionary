# codictionary

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Architecture (Work in Progress)

This project is being incrementally migrated towards a Clean Architecture layout:

- `lib/core/` shared utilities and DI (`core/di`).
- `lib/domain/` business logic: `entities`, `repositories` (abstractions), `usecases`.
- `lib/data/` implementations: `repositories`, `datasources`.
- `lib/presentation/` UI layer (to be populated as widgets/screens are migrated).

Initial scaffolding added:
- DI bootstrap: `lib/core/di/service_locator.dart`, `lib/core/di/initial_bindings.dart`.
- Domain examples: `WordEntity`, `WordRepository` interface, `AddWord` use case.
- Data bridge: `WordRepositoryImpl` wrapping existing storage service.

Bootstrap happens in `main()` calling `initServiceLocator()` and `registerInitialDependencies()`.

Next steps for contributors:
- Migrate features into `domain`/`data`/`presentation` slices gradually.
- Replace direct calls to legacy services with use cases (e.g., `AddWord`).
- Keep widgets thin; inject dependencies via the service locator for now.
