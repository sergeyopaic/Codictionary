# Project Architecture

This document describes the architecture, folder structure, and conventions used in this project.  
We follow **Clean Architecture** principles with **MVVM (Model–View–ViewModel)**. State is managed with plain Flutter **ChangeNotifier/ValueNotifier** ViewModels; dependency injection uses **get_it**.

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

```
lib/
├─ presentation/ # UI Layer
│ ├─ core/ # Shared UI elements
│ │ ├─ widgets/ # Shared reusable widgets
│ │ └─ theme/ # App themes & styling
│ └─ <feature_name>/ # Each feature's UI & controller
│   ├─ <feature_name>_view.dart # Root view
│   ├─ <feature_name>_view_model.dart # ViewModel (ChangeNotifier/ValueNotifier)
│   ├─ widgets/ # Feature-specific widgets/screens
│   └─ routing.dart # Feature-local route(s)
│
├─ domain/ # Business Layer
│ ├─ models/ # Pure domain models
│ ├─ repositories/ # Abstract repository interfaces
│ └─ usecases/ # Application-specific actions
│
├─ data/ # Data Layer
│ ├─ models/ # Integration models (DTOs, persistence entities if any)
│ ├─ services/ # API/database clients
│ ├─ mappers/ # Data ↔ Domain conversion
│ └─ repositories/ # Implementations of domain repositories
│
├─ composition/ # Dependency injection setup
│ ├─ di.dart # get_it service locator registrations
│ └─ env.dart # Environment config (staging, dev, prod)
│
├─ config/ # Build-time configs, constants, environment setup
├─ routing/ # App routing (GoRouter configuration)
├─ utils/ # Pure helper functions (non-layer specific)
├─ main.dart # Production entry point
├─ main_development.dart # Dev entry point
└─ main_staging.dart # Staging entry point
```


---

## 3. Dependency Rules

We enforce **strict layer boundaries**:

```
presentation ---> domain ---> data
```

- **Presentation**  
  - Can depend on: `domain`, `composition`, `config`, `utils`.
  - ❌ Must not import anything from `data` directly.

- **Domain**  
  - Pure Dart.  
  - Must not depend on: `presentation`, `data`, or Flutter SDK (UI).

- **Data**  
  - Can depend on: `domain`, `utils`.
  - Must not depend on: `presentation`.

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

- `di.dart`: get_it service locator setup (registers repositories, use-cases, router). Entry: `AppDI.init()`.
- `env.dart`: Environment-specific constants, base URLs, feature flags.

This concentrates dependency wiring in one place and keeps tests simple to override by registering alternative implementations in the locator.

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