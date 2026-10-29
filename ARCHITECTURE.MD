# Project Architecture

This document describes the architecture, folder structure and conventions of
the project as it is now. Plans that are not built yet are listed separately
in §11.

We follow **Clean Architecture** with **MVVM**. State lives in plain Flutter
`ChangeNotifier` ViewModels; dependencies are passed explicitly (constructor
injection from a single composition root, no service locator).

---

## 1. Overview

The code has three layers and one wiring point:

1. **Presentation** (`lib/presentation/`): screens, widgets, ViewModels,
   theme and interface texts. Depends on `domain` only.
2. **Domain** (`lib/domain/`): pure Dart business logic: entities, interfaces
   for repositories and external services, use cases, exceptions. Knows
   nothing about storage, HTTP or Flutter.
3. **Data** (`lib/data/`): implementations of the domain interfaces: JSON
   storage, the OpenAI and DeepL clients, the backup format. Works with
   domain entities at its boundary and maps to its own records inside.
4. **Composition** (`lib/composition/`): reads the config and connects data
   implementations to domain contracts. Nothing else imports `data`.

---

## 2. Folder Structure

The Flutter project is the repository root.

```
lib/
├─ main.dart              # Entry point: config → dependencies → settings → runApp
├─ composition/
│ ├─ app_config.dart      # Reads .env (missing or empty keys → local mode)
│ └─ app_dependencies.dart# buildUseCases / buildProductionUseCases
│
├─ presentation/
│ ├─ app.dart             # CodictionaryApp: strings, theme, MaterialApp, AppScope
│ ├─ app_scope.dart       # AppUseCases bundle + AppScope InheritedWidget
│ ├─ shell/               # Adaptive shell: sidebar (wide) or bottom bar (narrow)
│ ├─ dictionary/          # View, ViewModel, widgets/ (card, editor, details sheet, …)
│ ├─ vocabs/              # Collections: list, one collection, word picker
│ ├─ backup/              # Backup and restore screen
│ ├─ l10n/                # AppStrings, EnStrings, RuStrings, Russian Material texts
│ ├─ theme/               # Palette, tokens, light/dark themes, ThemeController
│ ├─ dialogs/ widgets/    # Shared dialogs and widgets
│
├─ domain/
│ ├─ entities/            # WordEntity, Vocabulary, AppSettings, DictionarySnapshot
│ ├─ repositories/        # WordRepository, VocabularyRepository, SettingsRepository
│ ├─ services/            # WordExplainer, Translator, BackupCodec, BackupFiles
│ ├─ usecases/            # AddWord, UpdateWord, ReorderWords, ExplainWord, backup, …
│ └─ exceptions/          # Storage, service, word and backup errors
│
├─ data/
│ ├─ storage/             # SafeJsonStorage over file (desktop/mobile) or localStorage (web)
│ ├─ remote/              # OpenAiExplainer, DeepLTranslator, retry/timeout helper
│ ├─ backup/              # JSON backup codec; backup files per platform
│ ├─ models/              # WordRecord, VocabularyRecord (JSON shape on disk)
│ └─ repositories/        # Word/Vocabulary/Settings repository implementations
│
└─ core/usecase.dart      # UseCase base type
```

Platform-specific code (files, `localStorage`, downloads) is chosen with
conditional imports inside `data/` (`create_storage_service.dart`,
`create_backup_files.dart`).

---

## 3. Dependency Rules

Checked by `test/architecture_test.dart`:

```
presentation ──► domain ◄── data
        ▲                    ▲
        └──── composition ───┘   (wires data implementations into domain contracts)
```

- **Presentation** may import `domain` only (use cases, entities, exceptions).
  It must not import `data`, `composition`, HTTP, storage or `.env` packages.
  It gets use cases from `AppScope`; ViewModels receive them in the
  constructor and never touch repositories.
- **Domain** is pure Dart: no Flutter, no `presentation`, `data` or
  `composition`. It declares an interface for everything external.
- **Data** may import `domain`, never `presentation` or `composition`.
- **Composition** is the only place that constructs data implementations.
- No global service locator (`GetIt` and similar) may be used. The `get_it`
  package is still listed in `pubspec.yaml` but nothing imports it.

---

## 4. Feature Definition

A **feature** is a cohesive unit of UI functionality the user can see and
interact with: a screen (the dictionary), a section of one, or a self-contained
widget with its own state (the word editor dialog). A single button or a purely
visual widget is not a feature.

---

## 5. MVVM Pattern

- **Model**: a domain entity.
- **View**: the widget tree.
- **ViewModel**: a `ChangeNotifier` that holds UI state, calls use cases and
  maps their results and errors to state.

Placement: `lib/presentation/<feature>/<feature>_view.dart` and
`<feature>_view_model.dart`, with parts in `widgets/`.

- **View**: owns the lifecycle (`initState`, `dispose`), shows loading, empty
  and error states, opens dialogs and messages, and turns errors into text.
  No business logic.
- **ViewModel**: orchestrates use cases. Examples from
  `DictionaryViewModel`: every operation is addressed by word id; slow
  requests carry a token so a late answer can't overwrite a newer one or
  revive a deleted word; a failed save is rolled back so the screen never
  shows unsaved data.

---

## 6. Composition Root

- `app_config.dart` reads `.env`. A missing file or empty key is not an
  error: that service runs in local mode (`isAvailable == false`, no
  requests).
- `app_dependencies.dart`:
  - `buildUseCases({storage, explainer, translator, backupFiles})` builds the
    whole graph (one repository of each kind per storage, all use cases) and
    returns an `AppUseCases` bundle.
  - `buildProductionUseCases(config)` adds the platform storage, the OpenAI
    and DeepL clients and the platform backup files.

`main.dart` builds the bundle once, loads the saved settings (theme) and
passes both to `CodictionaryApp`, which provides the bundle through
`AppScope`. Nothing is registered globally, so rebuilding the app has no side
effects. Tests call `buildUseCases` with fakes
(`test/helpers/test_dependencies.dart`) and get an independent graph per test.

---

## 7. Models & Mapping

- **Domain entities** (`domain/entities/`) are immutable and know nothing about
  storage. ViewModels and use cases work only with them.
- **Records** (`data/models/`) are the JSON shape on disk. They also read
  older formats (records without ids or dates, old field names) so existing
  files keep working.
- **Mapping** lives in the repository implementations (`_toEntity` /
  `_toRecord`); there is no separate mappers folder. Repositories accept and
  return entities only.
- **External services** (OpenAI, DeepL) return plain strings or throw a
  `ServiceException` with a `ServiceFailure` (offline, timeout, out of credit,
  …); raw responses never leave `data/remote/`.

---

## 8. Testing Strategy

Focus on **real user flows** and **business rules**; keep tests fast and
deterministic.

1. **UI flow tests** (`test/ui/`): drive the real `CodictionaryApp` with taps
   and typing and assert what the user sees. Example: `core_journey_test.dart`
   adds, searches, sorts, edits, deletes with Undo and restarts.
2. **Use-case and rule tests** (`test/usecases/`): business rules,
   concurrency, storage safety, the backup format, and the HTTP clients
   against a mock server (status codes, retries, timeouts, parsing).
3. **Fakes** (`test/fakes/`, `test/helpers/`): in-memory storage
   (`JsonStorageService`, `MemoryBackend`) under the **real** repositories and
   use cases, and fake AI/translation services, some of which let a test
   decide when and in which order answers arrive.
4. **Live smoke** (`smoke/`): one real request per paid API, run by hand or
   by the manual workflow. Never part of `flutter test` or regular CI.

Storage and HTTP code is tested directly where a mistake would lose data or
show wrong results (atomic writes on real temp files, damaged JSON, error
mapping). ViewModels are tested in isolation only where their state machine
is complex (`test/dictionary_view_model_test.dart`).

`docs/TEST_MATRIX.md` maps every critical scenario to its tests.

```
test/
├─ ui/        # Flows through the app
├─ usecases/  # Domain rules, storage and client behaviour
├─ fakes/     # In-memory storage backends
└─ helpers/   # testUseCases(), seed data, controllable fakes
smoke/        # Live API checks (manual)
```

---

## 9. Conventions

- **Files**: `lower_snake_case.dart`. Small related classes may share a file.
- **Views**: `<feature>_view.dart` / `<feature>_view_model.dart`, classes
  `FeatureView` / `FeatureViewModel`.
- **Use cases**: named with a verb (`AddWord`, `ReorderWords`), callable
  classes.
- **Errors**: domain exceptions (`StorageException`, `ServiceException`,
  `BackupFormatException`) carry facts, not texts; the UI turns them into
  words through `AppStrings`.
- **Texts**: every visible string is a member of `AppStrings`
  (`presentation/l10n/`), implemented by `EnStrings` and `RuStrings`; a
  missing translation is a compile error. Widgets read them with `context.s`.
- **Theme**: `AppTheme.light` / `AppTheme.dark` and tokens in
  `presentation/theme/`.
- **Widgets**: feature-specific in `presentation/<feature>/widgets/`, shared
  in `presentation/widgets/`.

---

## 10. Example Flow

**The user adds a word.**

1. The word editor (`WordEditorDialog`) calls `DictionaryViewModel.addWord`.
2. The ViewModel rejects a duplicate (also a double submit) and calls the
   `AddWord` use case.
3. `AddWord` creates the entity and calls `WordRepository.create`.
4. `WordRepositoryImpl` maps the entity to a `WordRecord`, and
   `SafeJsonStorage` writes the file atomically, keeping a `.bak`.
5. The ViewModel shows the word at once, then asks `ExplainWord` for an
   explanation in the background. When it arrives, `UpdateWord` saves it and
   the card updates; if it fails, the card shows why.
6. If saving fails, the ViewModel rolls back and the View shows "Not saved".

---

## 11. Not Implemented Yet

- **Server gateway** for OpenAI and DeepL. Today the keys are bundled in the
  app from `.env`, and the web build cannot translate because DeepL blocks
  browser requests (CORS). See `docs/RELEASE.md`.
- **Full Material localization** (`flutter_localizations`). Until a
  maintainer adds it, `presentation/l10n/material_ru.dart` translates the
  Material texts the app shows; the rest falls back to English.
- **Verified releases** on Android, iOS, macOS, Linux and Windows MSIX: see
  the matrix in `docs/RELEASE.md`.
