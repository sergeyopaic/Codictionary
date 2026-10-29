# Test matrix

Which critical scenario is checked where. Automated tests run in CI on every
pull request (`.github/workflows/ci.yml`); they use in-memory storage and
fake AI/translation services, so they are fast, free and deterministic.
Paid APIs are checked separately and by hand (see "Live API smoke").

Paths are relative to `test/`.

## User actions

| Scenario | Through the UI | Rules and edge cases |
|---|---|---|
| Add, search, sort, edit, delete + Undo, restart — the whole journey | `ui/core_journey_test.dart` | — |
| Add a word (translation, explanation in the background) | `ui/core_journey_test.dart`, `ui/word_editor_flow_test.dart` | `usecases/add_word_without_ai_test.dart`, `dictionary_view_model_test.dart` |
| Edit a word | `ui/core_journey_test.dart` | `dictionary_view_model_test.dart` (which explanations survive an edit), `usecases/word_persistence_test.dart` |
| Search | `ui/core_journey_test.dart`, `ui/app_shell_flow_test.dart` | `usecases/word_order_test.dart` (dragging while searching) |
| Manual order (drag) | `ui/app_shell_flow_test.dart` (blocked while searching) | `usecases/word_order_test.dart` |
| Sort | `ui/core_journey_test.dart` | `usecases/word_order_test.dart` (sort never changes the manual order) |
| Delete and Undo (one word, many words) | `ui/core_journey_test.dart` | `usecases/word_order_test.dart` (Undo restores the place), `dictionary_view_model_test.dart` (every field) |
| Collections | `ui/vocabularies_flow_test.dart` | `usecases/vocabularies_test.dart` |
| Backup and restore | `ui/backup_flow_test.dart` | `usecases/backup_test.dart` |
| First run, example words | `ui/app_shell_flow_test.dart` | `usecases/first_run_test.dart` |
| Theme is remembered | `ui/theme_persistence_test.dart` | — |
| Russian / English interface, keyboard, labels | `ui/localization_test.dart` | — |
| Layout at phone…desktop sizes, 200 % text | `ui/layout_stress_test.dart` | — |

## Data safety

| Scenario | Tests |
|---|---|
| Everything survives a restart | `ui/core_journey_test.dart`, `usecases/word_persistence_test.dart`, `usecases/vocabularies_test.dart` |
| Damaged or unreadable file: reported, never overwritten; restore from `.bak` | `usecases/storage_safety_test.dart`, `usecases/dictionary_storage_errors_test.dart`, `ui/app_shell_flow_test.dart` |
| Failed write: change rolled back, nothing shown as saved | `usecases/dictionary_storage_errors_test.dart`, `usecases/vocabularies_test.dart`, `usecases/word_order_test.dart` |
| Atomic writes on disk, interrupted write | `usecases/storage_safety_test.dart` (real files in a temp folder) |
| Files from older app versions (migrations) | `usecases/storage_safety_test.dart`, `usecases/word_persistence_test.dart` (legacy records), `usecases/vocabularies_test.dart` (collections without ids) |
| Damaged settings fall back to defaults | `ui/theme_persistence_test.dart` |
| Late or overlapping responses, double taps | `usecases/dictionary_concurrency_test.dart`, `ui/word_editor_flow_test.dart` |

## Network and configuration

| Scenario | Tests |
|---|---|
| No API keys (local mode): no requests, no errors | `usecases/add_word_without_ai_test.dart`, `ui/word_editor_flow_test.dart`, `usecases/ai_clients_test.dart` |
| Offline, timeout, 429, 5xx, out of credit, bad answers | `usecases/ai_clients_test.dart` (real HTTP mapping against a mock server), `usecases/add_word_without_ai_test.dart` |
| Errors never show the key or the raw response | `usecases/ai_clients_test.dart` |
| Real request/response format of OpenAI and DeepL | `smoke/api_smoke_test.dart` (manual, see below) |

## Architecture and build

| Check | Where |
|---|---|
| Layer boundaries, no global service locator | `architecture_test.dart` |
| Format, analyzer, all tests | CI |
| Web release build compiles | CI (`flutter build web --release`) |
| No API keys in the repository or in the web build | CI (`tools/check_no_secrets.dart`) |

CI creates a `.env` with empty keys, so the build it checks is in local mode.

## Live API smoke

`smoke/api_smoke_test.dart` sends one request to OpenAI and one to DeepL.
It is outside `test/`, so `flutter test` never runs it. Run it:

- on GitHub: Actions → **API smoke (manual)** → Run workflow. It uses the
  repository secrets `OPENAI_API_KEY` and `DEEPL_API_KEY`;
- locally: `OPENAI_API_KEY=… DEEPL_API_KEY=… flutter test --no-pub smoke`.

A service whose key is not set is skipped. Last run (2026-10-29): DeepL
passed; OpenAI failed with "out of credit" (T11).

## Manual checks per release

Automated tests cannot cover these. See `RELEASE.md` for the platform
matrix and where the results are recorded.

1. Install the release build on the target platform.
2. Add a word: the translation and the explanation appear, or a clear error.
3. Restart the app: the word is still there.
4. Turn the network off and add a word: it is saved and the error is clear.
5. Save a backup file and restore it.
