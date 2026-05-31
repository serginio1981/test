# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This repo holds **two independent projects** that share no code or build system. Work within one project at a time; don't cross-wire them.

| Project | Location | Stack | Targets |
| --- | --- | --- | --- |
| `bird_sound_identifier` | repo root (`lib/`, `android/`, `ios/`, `pubspec.yaml`) | Flutter / Dart | Android, iOS |
| `band-sound-generator` | `band-sound-generator/` | Vanilla JS + Web Audio API (no build) | Browser / GitHub Pages |

The default-branch GitHub Actions workflow (`.github/workflows/static.yml`) deploys the whole repo to GitHub Pages, which serves the web app at `https://serginio1981.github.io/test/band-sound-generator/`.

---

# Project 1 — `bird_sound_identifier` (Flutter)

## Project

Flutter app (`bird_sound_identifier`) that records bird songs and identifies species via the BirdNET-Analyzer API, then enriches the result with photos, Wikipedia text and recent eBird sightings. Targets Android and iOS. Dart SDK `>=3.3.0 <4.0.0`, Flutter `>=3.22.0`.

## Common commands

```bash
flutter pub get                     # install deps
flutter run                         # run on attached device/emulator
flutter run -d <device-id>          # pick a specific device (flutter devices to list)
flutter analyze                     # static analysis (uses analysis_options.yaml)
flutter test                        # run unit/widget tests
flutter test test/path/to_test.dart # run a single test file
flutter test --name "substring"     # run tests whose name matches
flutter build apk                   # release APK
flutter build ios --no-codesign
```

Hive adapters are generated. After changing any `@HiveType` model, regenerate with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

(`*.g.dart` and `*.freezed.dart` are gitignored and excluded from the analyzer.)

### Environment

`.env` is loaded at startup by `flutter_dotenv` and is declared as a Flutter asset in `pubspec.yaml` — it must exist or `main()` will throw. Copy `.env.example` to `.env` and fill in:

- `BIRDNET_BASE_URL` — BirdNET-Analyzer endpoint (self-hosted or community).
- `EBIRD_API_KEY` — used to fetch recent sightings.

User-facing overrides (eBird key, BirdNET URL, min confidence, recording duration) live in `flutter_secure_storage` via `SecureStorageService` and take precedence over `.env` defaults at request time.

## Architecture

Clean Architecture by feature. Top-level layout:

```
lib/
  main.dart                # loads .env, opens Hive boxes, registers adapters, runApp
  app.dart                 # MaterialApp.router wiring AppTheme + AppRouter
  core/                    # cross-cutting: constants, network, storage, theme, errors
  shared/                  # app-wide providers, router, common widgets
  features/<feature>/
    domain/                # entities, repository interfaces, usecases (pure Dart)
    data/                  # datasources, models (Hive/JSON), repository impls
    presentation/          # screens, widgets, Riverpod providers/notifiers
```

Features: `record`, `identification`, `bird_detail`, `history`, `settings`. Dependencies always point inward — `presentation` → `domain` ← `data`. Concrete `data` types are only referenced from `shared/providers/providers.dart` and from within their own feature.

### Dependency injection

All wiring is manual via Riverpod `Provider`s in `lib/shared/providers/providers.dart`. Add new datasources/repositories/usecases there rather than constructing them inside widgets. Screen-local state lives in `StateNotifierProvider`s inside each feature's `presentation/providers/`.

### Navigation

`go_router` configured in `lib/shared/router/app_router.dart`. The three primary tabs (`/record`, `/history`, `/settings`) live inside a `StatefulShellRoute.indexedStack` rendered by `AppBottomNav`. `/results` and `/bird/:speciesCode` are modal routes outside the shell and receive their argument via `state.extra` (cast to `RecordingSession` / `IdentifiedBird` — keep this contract when adding callers).

### Networking

`core/network/dio_client.dart` exposes four pre-configured `Dio` singletons (BirdNET, eBird, Wikipedia, iNaturalist), each with its own base URL from `ApiConstants`. Use the top-level getters (`birdNetDio`, `eBirdDio`, `wikipediaDio`, `iNatDio`) from datasources — do not instantiate `Dio` yourself. The eBird token is injected at runtime via `DioClient.updateEBirdToken` (call from settings flow after the user saves a key). Convert `DioException` to the app's `AppException` hierarchy with `DioClient.mapToAppException` at datasource boundaries.

### Errors

`core/errors/app_exception.dart` defines a `sealed class AppException` with `NetworkException`, `ApiException`, `AudioRecordingException`, `PermissionDeniedException`, `StorageException`, `IdentificationException`. Throw these from data/domain; surface `.message` in the UI.

### Persistence

- **Hive** (`core/storage/hive_service.dart`) — single box `history` of `HistoryEntryModel` (`typeId: 0`). Box is opened in `main()` before `runApp`. When adding new persisted types, register the adapter in `main()` and open the box in `HiveService.openBoxes()`; pick a unique `typeId`.
- **flutter_secure_storage** (`SecureStorageService`) — user secrets and preferences only (eBird key, BirdNET URL override, min confidence, recording duration). All access goes through the static methods.

### Recording → identification flow

1. `RecorderNotifier` (`features/record/.../recorder_provider.dart`) drives `AudioRepository` → `AudioRecorderDatasource`, which records 48 kHz mono WAV to the temp dir and streams amplitude every 100 ms.
2. On stop, a `RecordingSession` (path, start time, duration, optional lat/lng) is produced and the router navigates to `/results` with it as `extra`.
3. `IdentifyBirdUsecase` calls `BirdNetRemoteDatasource.analyze`, which posts the WAV as `multipart/form-data` with `sensitivity`, `min_conf`, `date`, and optional `lat`/`lon`. `min_conf` comes from `SecureStorageService.getMinConfidence()` (default `0.1`).
4. `IdentificationRepositoryImpl` deduplicates by `scientificName` keeping the highest confidence and sorts descending.
5. From the result, `BirdDetailRepository` fans out in parallel to Wikipedia (summary), iNaturalist (photos) and eBird (recent sightings near the user). Each enrichment source is independently fault-tolerant — failures fall back to empty/default values rather than aborting the screen.

## Conventions

Lint rules in `analysis_options.yaml` extend `package:flutter_lints/flutter.yaml` and additionally enforce: `always_declare_return_types`, `avoid_print` (use the `logger` package), `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_fields`, `prefer_single_quotes`, `sort_child_properties_last`, `use_key_in_widget_constructors`. Run `flutter analyze` before committing.

Entities are plain Dart with value-equality where it matters (`IdentifiedBird` is equal by `scientificName`). Data-layer models expose `toEntity()` / `fromEntity()` to convert at the boundary — keep domain types free of `package:hive`/`package:dio` imports.

---

# Project 2 — `band-sound-generator` (web app)

## Project

A self-contained, build-free web app (HTML + vanilla JS + the Web Audio API) for generating sounds and rehearsing arrangements. It bundles a subtractive synthesizer, a 32-step sequencer preloaded with an editable interpretation of **«Estrechez de Corazón» (Los Prisioneros)**, a piano-roll editor, and a playable keyboard. UI strings are in Spanish. See `band-sound-generator/README.md` for the full user guide.

## Common commands

No package manager, no build step, no tests. Open the file directly or serve statically:

```bash
# Open directly (works over file://)
xdg-open band-sound-generator/index.html      # Linux
open band-sound-generator/index.html          # macOS

# Or serve statically
cd band-sound-generator && python3 -m http.server 8000   # http://localhost:8000
```

Browsers require a user gesture (click/tap) before audio can start.

## Architecture

Scripts are loaded as **classic scripts (not ES modules)** from `index.html` in dependency order, so they share a single global scope and the app runs from `file://` with no server. Load order matters: `synth.js → song.js → sequencer.js → app.js → auth.js`.

```
band-sound-generator/
├── index.html        # markup + script tags (login overlay, transport, tracks, synth panel, keyboard)
├── css/style.css
└── js/
    ├── synth.js      # AudioEngine (stereo dry bus + filtered-feedback delay + compressor)
    │                 # and the Synth class (unison oscillators, lowpass w/ envelope, ADSR);
    │                 # plus note helpers (midiToFreq, midiToName, isBlackKey)
    ├── song.js       # CHORD_LIBRARY, default patches, and the song data
    │                 # (32 steps = 4 bars of eighth notes in 4/4; bass/lead arrays + per-bar chords)
    ├── sequencer.js  # Sequencer: lookahead scheduler driven by a coarse setInterval against
    │                 # the AudioContext clock; drainVisual() exposes the current step for the UI
    ├── app.js        # all UI wiring: piano roll, chord selectors, synth panel, keyboard,
    │                 # transport, and localStorage persistence
    └── auth.js       # optional Google Identity Services login gate (IIFE)
```

### Audio scheduling

`Sequencer` follows the canonical Web Audio pattern: a coarse `setInterval` (25 ms) wakes up and schedules every step whose time falls within a `lookAhead` (0.12 s) horizon against the precise `AudioContext` clock. The UI never drives timing — it polls `drainVisual()` to highlight the most recent step that has actually sounded. Step duration is an eighth note (`60 / bpm / 2`).

### Persistence

Song edits and synth patches are auto-saved to `localStorage`; the “Restablecer” button restores the defaults from `song.js`. The login session is cached under `band-sound-generator:user` until the Google token expires (~1 h) or the user signs out.

### Google login gate (`auth.js`)

`auth.js` runs as an IIFE that shows a full-screen overlay and blocks keyboard/pointer events until the user signs in with Google Identity Services. Behavior is gated by the `GOOGLE_CLIENT_ID` constant at the top of the file:

- **Empty string** → login is skipped (development mode); the studio loads immediately.
- **A real OAuth client ID** → the login screen is enforced (this is the current state — a client ID is configured).

> This is a 100% client-side app with no backend, so the gate is **cosmetic**: it identifies the visitor and shows their name/photo, but a technical user can bypass it. Real protection would require verifying the Google token on a server. The README’s “Configurar el login de Google” section documents how to provision the client ID and authorized origins (`https://serginio1981.github.io`, `http://localhost:<port>`).

## Conventions

- Every JS file starts with `'use strict';`. Comments and UI copy are in Spanish — keep new additions consistent.
- Keep the app dependency-free and build-free; don't introduce npm, bundlers, or ES-module `import`/`export` (it would break `file://` usage and the script-tag load order). The only external script is Google's GSI client, loaded from a CDN in `index.html`.
- MIDI note numbers are the internal pitch representation throughout; use the helpers in `synth.js` to convert.

## Deployment

`.github/workflows/static.yml` deploys the repo to GitHub Pages on push to its trigger branch and via manual `workflow_dispatch`. It uploads the whole repository as the Pages artifact (`path: '.'`), so the web app is reached at the `band-sound-generator/` subpath. No build runs — the static files are published as-is.
