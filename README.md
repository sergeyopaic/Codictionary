# Codictionary

A personal vocabulary app for learning English words, built with Flutter. Add a
word, let Cody the squirrel fill in the Russian translation, and ask him for a
quick or in-depth explanation with examples when a translation isn't enough.

![Dictionary screen: sidebar, a banner with word counts, search, sorting and a grid of word cards](docs/screenshots/dictionary.png)

## Features

- **Word cards**: the English word, its Russian translation and a preview of the
  saved explanation, in a grid that adapts to the screen width.
- **Auto-translate**: type the English word and the Russian field is filled in
  through the DeepL API. Switch it off to type your own translation; a
  translation you typed is never overwritten.
- **Explanations**: a quick or an in-depth explanation of a word (meaning,
  usage, examples), written in Russian through the OpenAI API. A new word is
  saved at once and explained in the background; if that fails, the card says
  why and you can retry.
- **Search** across English and Russian. If nothing matches, the search offers
  to add the word you typed.
- **Order**: sort A–Z, Z–A or newest first, or drag cards into your own order
  (long press). Sorting never changes your own order.
- **Delete with Undo**, for one word or several selected at once.
- **Vocabularies**: collections with a name, description and icon. A word can
  be in several of them; deleting a collection keeps its words.
- **Backup**: save the whole dictionary (words, explanations, order,
  collections) to a file or the clipboard, and restore it. A safety copy of the
  current data is kept before every restore.
- **Interface in Russian or English**, following the system language.
- **Light and dark themes**: follows the system, or your choice is remembered.
- **Adaptive layout**: a sidebar on wide screens, a bottom bar on phones; works
  with large text.
- **Keyboard shortcuts**: `Ctrl+N` (`⌘N` on macOS) adds a word, `Ctrl+F` jumps
  to search, `Esc` leaves selection mode.

| Word details | Adding a word |
| --- | --- |
| ![Word details sheet with Quick and In depth tabs and Cody's explanation](docs/screenshots/word-details.png) | ![Add a word dialog with English and Russian fields and the Auto-translate switch](docs/screenshots/add-word.png) |

![Vocabularies screen with three collections](docs/screenshots/vocabularies.png)

<img src="docs/screenshots/phone-dark.png" alt="Phone layout in the dark theme with bottom navigation, Russian interface" width="300">

The screenshots are from the web build with sample data.

## Run it locally

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
3.35 (Dart 3.9). CI uses Flutter 3.35.4.

1. Create a `.env` file in the project root. The file must exist, because it
   is bundled as an asset, but the keys are optional:

   ```
   OPENAI_API_KEY=
   DEEPL_API_KEY=
   ```

   - **Without keys (local mode)** the app works fully offline: you type
     translations yourself and there are no AI explanations. Nothing is sent
     anywhere and no errors are shown.
   - **With keys** auto-translate (DeepL; a free key ends in `:fx`) and
     explanations (OpenAI) are turned on. Each key works on its own.

2. Run the app:

   ```bash
   flutter run
   ```

   Pick a device with `-d`, for example `-d windows` or `-d chrome`.

Dependencies are pinned in `pubspec.lock`. Don't change `pubspec.yaml` or
`pubspec.lock` in a contribution; dependency changes are made by the
maintainers.

### About the API keys

`.env` is bundled into the app, so anyone with a build can read the keys in
it. Use your own keys for local runs only, and don't publish a build that
contains real keys. A server gateway that keeps the keys out of the app is
planned but not built yet. The web build also can't translate: DeepL blocks
requests from browsers.

## Where data is stored

Everything stays on the device: there is no account and no backend.

| | Dictionary, collections, settings | Backups |
|---|---|---|
| Android, iOS, desktop | `dictionary.json`, `vocabularies.json`, `settings.json` in the app's documents folder (on Windows: `Documents`) | `codictionary_backups/` in the same folder |
| Web | the browser's `localStorage` | downloaded as files |

Every save replaces the file in one step and keeps the previous version as
`<name>.bak`. If a file is damaged, the app does not overwrite it: it offers
to restore the last good copy and keeps the damaged data aside.

## Platforms

Builds exist for Android, iOS, web, Windows, macOS and Linux, but not all of
them have been checked yet. [docs/RELEASE.md](docs/RELEASE.md) shows what was
verified on which platform, the known limitations and the release checklist.

## Checks

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub
```

`tools/pre-commit.sh` runs all of them plus the secrets check.

The tests use in-memory storage and fake AI and translation services, so they
are fast and free. They cover user flows through the real UI (add, edit,
search, sort, delete and Undo, restart, collections, backup), data safety
(damaged files, failed writes, old file formats), network failures and both
interface languages. [docs/TEST_MATRIX.md](docs/TEST_MATRIX.md) maps each
scenario to its tests.

CI (GitHub Actions) runs on every pull request and push to `main`: format,
analyzer, tests, a web release build, and `tools/check_no_secrets.dart` on
the repository and the build. CI uses a `.env` without keys. The paid APIs
are checked by the separate **API smoke (manual)** workflow, which only runs
when started by hand.

## Project structure

- `lib/main.dart`: the entry point. It reads `.env`, builds the dependencies,
  loads the saved settings and starts the app.
- `lib/composition/`: the only place that connects the data layer to the
  domain (`app_config.dart`, `app_dependencies.dart`).
- `lib/presentation/`: the UI.
  - `shell/`: the adaptive app shell (sidebar or bottom bar);
  - `dictionary/`, `vocabs/`, `backup/`: the screens, their view models and
    widgets;
  - `theme/`: colours taken from Cody, light and dark themes, spacing and
    motion tokens, the theme controller;
  - `l10n/`: all interface texts in English and Russian;
  - `dialogs/`, `widgets/`: shared dialogs and widgets.
- `lib/domain/`: the business logic in pure Dart: `entities`, `repositories`
  and `services` (interfaces), `usecases`, `exceptions`.
- `lib/data/`: the implementations: safe JSON storage (`storage/`), OpenAI and
  DeepL clients (`remote/`), the backup format and files (`backup/`), JSON
  records (`models/`) and repositories.
- `test/`: `ui/` (flows through the app), `usecases/` (rules), `fakes/`,
  `helpers/`. Live API checks are in `smoke/`.
- `tools/`: the pre-commit script and the secrets check.

## Architecture

Clean Architecture with MVVM: `presentation → domain ← data`, and only
`lib/composition/` connects the two. [ARCHITECTURE.MD](ARCHITECTURE.MD)
describes the rules; `test/architecture_test.dart` enforces them.
