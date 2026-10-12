# Codictionary

A personal vocabulary app for learning English words, built with Flutter. Add a
word, get the Russian translation filled in automatically, and ask for a short or
detailed explanation with examples when you want more than a translation.

![Codictionary main screen: a grid of word cards with search and sorting](docs/screenshots/dictionary.png)

## Features

- **Word cards** — English word and Russian translation in a grid that adapts to
  the screen width.
- **Auto-translate** — type the English word and the Russian field is filled in
  through the DeepL API. Turn it off to enter your own translation.
- **Explanations** — a short or a detailed explanation of a word (meaning, usage,
  examples), generated in Russian through the OpenAI API and saved with the card.
- **Search** across both English and Russian.
- **Sorting** A–Z, Z–A or by date added, plus drag-and-drop to reorder by hand.
- **Bulk actions** — select several cards and delete them at once, with undo.
- **Multiple vocabularies** — create, rename and delete separate word lists, each
  with its own icon.
- **Duplicate check** — the same English word can't be added to a vocabulary twice.

![Add Word dialog with the Auto-translate option](docs/screenshots/add-word.png)

## How it stores data

Everything stays on the device — there is no account and no backend.

- Mobile and desktop: a `dictionary.json` file in the app's documents directory.
- Web: the browser's `localStorage`.

## Tech

- Flutter / Dart, Material 3
- `get_it` for dependency injection
- `http` for the DeepL and OpenAI calls
- `flutter_dotenv` for API keys
- `reorderable_grid_view` for drag-and-drop

The project has Flutter targets for Android, iOS, web, Windows, macOS and Linux.
The screenshots above are from the web build.

## Run it locally

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.9
or newer).

1. Create a `.env` file in the project root:

   ```
   OPENAI_API_KEY=your-openai-key
   DEEPL_API_KEY=your-deepl-free-key
   ```

   The app won't start if `.env` is missing or empty. Without valid keys the app
   still runs, but auto-translate and explanations return errors.

2. Install dependencies and run:

   ```bash
   flutter pub get
   flutter run
   ```

`.env` is bundled into the app as an asset, so anyone with a build can read the
keys in it. Don't publish a build that contains real keys.

## Tests

```bash
flutter test
```

CI (GitHub Actions) runs the format check, `flutter analyze` and the tests on every
push and pull request.

## Architecture (work in progress)

The code is being migrated step by step towards Clean Architecture with MVVM. The
target layout and rules are described in [ARCHITECTURE.MD](ARCHITECTURE.MD).

- `lib/core/` — shared utilities and DI (`core/di`).
- `lib/domain/` — business logic: `entities`, `repositories` (abstractions),
  `usecases`.
- `lib/data/` — implementations: `repositories`, `datasources`.
- `lib/presentation/` — UI: views, view models, dialogs and widgets.
- `lib/services/` — legacy services (storage, DeepL, OpenAI) that the data layer
  still wraps.

Bootstrap happens in `main()`, which calls `registerInitialDependencies()` and
registers the app services in the service locator.

Next steps:

- Migrate features into `domain` / `data` / `presentation` slices gradually.
- Replace direct calls to legacy services with use cases (e.g. `AddWord`).
- Keep widgets thin; inject dependencies through the service locator for now.
