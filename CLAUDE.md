# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
