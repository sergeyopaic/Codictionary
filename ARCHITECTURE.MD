# Project Architecture

This document describes the architecture, folder structure, and conventions used in this project.  
We follow **Clean Architecture** principles with **MVVM (Model–View–ViewModel)**. State is managed with plain Flutter **ChangeNotifier/ValueNotifier** ViewModels; dependencies are passed explicitly (constructor injection from a single composition root, no service locator).

---

## 1. Overview

Our codebase is organized into **three main layers**:

1. **Presentation (UI Layer)**  
   - User interface, widgets, navigation, and view models (controllers).  
   - Depends **only** on the `domain` layer (via repository interfaces & use-cases).  
   - Contains **features**—each representing a cohesive user use-case (screen, flow, or interactive component with its own state).

2. **Domain (Business Layer)**  
   - Pure business logic, independent of Flutter and external frameworks.  
   - Contains:
     - Business **models**
     - **Repository interfaces** (abstractions)
     - **Use-cases** (application-specific actions)
   - No knowledge of persistence, APIs, or UI.

3. **Data (Persistence/Integration Layer)**  
   - Implements the repository interfaces from `domain`.  
   - Contains:
     - **Models** for integration (DTOs, persistence entities if needed)
     - **Services** (API clients, database services, platform integrations)
     - **Mappers** to convert between external models and domain models  
   - Prefer exposing and working with **domain models** at repository boundaries; map to/from DTOs/entities only at the edges.
   - Depends only on `domain` (to implement its abstractions).

---

## 2. Folder Structure

Actual layout (the Flutter project lives in the repository root):

```
lib/
├─ main.dart            # Entry point: load config, build dependencies, runApp
├─ composition/         # Composition root — the only code that imports data/
│ ├─ app_config.dart    # Reads .env (missing keys → local mode)
│ └─ app_dependencies.dart # buildUseCases / buildProductionUseCases
│
├─ presentation/        # UI layer
│ ├─ app.dart           # CodictionaryApp (MaterialApp + AppScope)
│ ├─ app_scope.dart     # AppUseCases bundle + AppScope InheritedWidget
│ ├─ theme/ widgets/ dialogs/ shell/
│ ├─ dictionary/        # dictionary_view.dart, dictionary_view_model.dart, widgets/
│ └─ vocabs/
│
├─ domain/              # Business layer (pure Dart)
│ ├─ entities/          # WordEntity, Vocabulary
│ ├─ repositories/      # WordRepository, VocabularyRepository (interfaces)
│ ├─ services/          # WordExplainer, Translator (interfaces)
│ ├─ usecases/          # AddWord, UpdateWord, ExplainWord, TranslateWord, …
│ └─ exceptions/        # Storage, service and word errors
│
├─ data/                # Implementations of domain contracts
│ ├─ models/            # WordRecord (JSON shape on disk)
│ ├─ storage/           # SafeJsonStorage + file / localStorage backends
│ ├─ remote/            # OpenAiExplainer, DeepLTranslator, retry/timeout helper
│ └─ repositories/      # WordRepositoryImpl, VocabularyRepositoryImpl
│
└─ core/usecase.dart    # UseCase base type
```

---

## 3. Dependency Rules

We enforce **strict layer boundaries** (checked by `test/architecture_test.dart`):

```
presentation ──► domain ◄── data
        ▲                    ▲
        └──── composition ───┘   (wires data implementations into domain contracts)
```

- **Presentation**
  - Can depend on: `domain` only (use cases, entities, exceptions).
  - ❌ Must not import `data`, `composition`, HTTP, storage or `.env` packages.
  - Gets its use cases from `AppScope`; ViewModels receive them via the constructor.

- **Domain**
  - Pure Dart.
  - Must not depend on: `presentation`, `data`, `composition`, or Flutter.
  - Declares interfaces for everything external (repositories, `WordExplainer`, `Translator`).

- **Data**
  - Can depend on: `domain`.
  - Must not depend on: `presentation` or `composition`.

- **Composition**
  - The only place that constructs data implementations and connects them to domain contracts.

---

## 4. Feature Definition

A **feature** is a cohesive unit of UI functionality—something the user can see and interact with.  
Examples:
- Entire screen (e.g., Settings screen)
- Section of a screen (e.g., Counter list in a sidebar)
- Self-contained widget with its own state (e.g., Filter dialog)

**Not a feature**:  
- A single button inside a screen (unless it owns unique state and logic)
- Purely visual widgets without behavior

---

## 5. MVVM Pattern

We treat our controllers as **ViewModels** built on Flutter notifiers:

- **Model**: Domain model (pure business entity).
- **View**: Flutter widget tree (screens, UI components).
- **ViewModel**: `ChangeNotifier`/`ValueNotifier` class that:
  - Holds and updates UI state.
  - Calls domain **use-cases**.
  - Maps domain results to UI state.

### Feature Views

- **Placement**:
  - `lib/presentation/<feature>/<feature>_view.dart` (View)
  - `lib/presentation/<feature>/<feature>_view_model.dart` (ViewModel)
  - Co-locate the View and ViewModel in the feature root; compose UI pieces from `widgets/`.

- **Responsibilities (View)**:
  - Own all view lifecycle/initialization: `initState`, `didUpdateWidget`, `dispose`, and any setup needed for the feature screen.
  - Keep widget logic minimal; handle only UI state gates (e.g., loading, empty, error) and compose child widgets.
  - No business logic, data fetching, or mapping; delegate to the ViewModel and use-cases.

- **Responsibilities (ViewModel)**:
  - Orchestrate use-cases and map results to immutable UI state.
  - Expose simple properties/streams/notifiers for the View to render.
  - Avoid direct framework dependencies other than notifiers.

---

## 6. Composition Root

Located in `lib/composition/`.

- `app_config.dart`: reads `.env`. A missing file or key is not an error; the affected service runs in local mode.
- `app_dependencies.dart`:
  - `buildUseCases({storage, explainer, translator})` builds the whole object graph (one repository per storage, all use cases) and returns an `AppUseCases` bundle.
  - `buildProductionUseCases(config)` adds the platform storage and the OpenAI / DeepL clients.

`main.dart` calls `buildProductionUseCases` once and passes the result to `CodictionaryApp`, which provides it through `AppScope`. Nothing is registered globally, so rebuilding the app has no side effects. Tests call `buildUseCases` with fakes (`test/helpers/test_dependencies.dart`) and get an independent graph per test.

---

## 7. Models & Mapping

- **Domain models**:  
  - Immutable, persistence-agnostic
  - Live in `domain/models/`
  - Used by ViewModels & Use-cases

- **Data models**:  
  - Specific to persistence or API (DTOs, entities)
  - Live in `data/models/`
  - Can be mutable; never leak into presentation

- **Mappers**:  
  - Live in `data/mappers/`
  - Convert between domain models and data models

- **Domain-first boundaries**:
  - Repositories accept and return domain models.
  - Map external data (API/DB) to domain immediately upon entry.
  - Use DTOs/entities only at IO boundaries; do not surface them to UI or domain.

---

## 8. Testing Strategy

Our testing approach balances confidence with development velocity (solo dev context).  
The focus is on **real user flows** and **domain business logic**, while skipping low-value layers.

### Goals
- Verify critical user flows end-to-end (without real DB/network).
- Lock down business rules in the domain layer.
- Minimize test maintenance overhead.

### Scope

1. **UI Flow Tests (Presentation Layer)**
   - Represent real app user actions (taps, navigation, state changes).
   - Run with **fake repositories** to keep flows deterministic.
   - Cover happy paths plus a few key error/edge cases.
   - Assert visible outcomes and navigation, not internal state.

2. **Domain Use-Case Unit Tests**
   - Cover the core business rules, validations, and orchestration logic.
   - Use **in-memory fakes** for repositories.
   - Keep tests pure, fast, and focused on input → output behavior.

3. **Fakes**
   - Centralized fake implementations of repositories/services.
   - Used across both UI and domain tests.
   - Simple in-memory state only; mimic contracts, not internals.

### Explicitly Out of Scope
- **Data Layer Unit Tests:** Repositories are treated as glue; tested indirectly through fakes.  
  *Exception: add a thin smoke test only if mapping/error handling becomes complex.*
- **ViewModel Unit Tests:** Logic is exercised via UI flow tests.  
  *Exception: add isolated tests if a view model grows into a complex state machine.*

### Optional “Thin Rails”
- Contract tests to ensure fakes remain faithful to repository contracts.
- A few golden snapshots for critical UI states (loading, error, populated).
- Smoke checks for navigation/deep links.

### Test Organization

```
test/
├─ ui/ # User and app flows (presentation layer) tests
├─ usecases/ # Domain layer usecases unit tests
├─ fakes/ # In-memory repo/service fakes
└─ helpers/ # Test harness utilities (e.g. app wrapper, overrides)
```

### Principles
- Cover **what matters to users** (flows & business rules).
- Keep tests **fast, deterministic, and cheap to maintain**.
- Add extra layers of testing only when complexity/risk justifies it.

---

## 9. Conventions

- **File naming**:  
  - Lowercase_with_underscores.dart
  - One public class/typedef per file
- **Feature View naming**:
  - Files: `<feature>_view.dart`, `<feature>_view_model.dart`
  - Classes: `FeatureView`, `FeatureViewModel`
- **State management**:  
  - Prefer `ChangeNotifier`/`ValueNotifier` for ViewModels.
  - Keep ViewModels focused and testable; expose immutable state when possible.
- **DTOs & Entities**:  
  - Suffix with `Dto` or `Entity`
- **Use-cases**:  
  - Named with a verb (e.g., `FetchUserProfile`, `UpdateThemeMode`)
- **Theme**:  
  - `lightTheme` & `darkTheme` exported from `presentation/core/theme/`
- **Widgets**:  
  - Feature-specific → `presentation/<feature>/widgets/`
  - Shared UI → `presentation/core/widgets/`

---

## 10. Example Flow

**User taps "Add Item" → ViewModel → Use-case → Repository → Data source → Mapper → Domain Model → UI update**

1. `AddItemButton` widget calls method in `ItemController`.
2. `ItemController` calls `AddItem` use-case from `domain/usecases/`.
3. `AddItem` calls `ItemRepository` (interface).
4. Data layer implementation saves to a database or calls an API via a service.
5. Mapper converts DTO/entity → Domain model.
6. Domain model returned to ViewModel.
7. ViewModel updates state → UI rebuilds.

---

**This structure keeps:**
- UI modular and testable
- Business rules decoupled from frameworks
- Data sources swappable without touching business logic
- Clear boundaries between concerns

```
Presentation (features) → Domain (use-cases) → Data (impl)
```

---