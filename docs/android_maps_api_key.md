# Android — Google Maps API Key (PR-005)

**Epic B Safety · RK-062 (keys) · EV-144**  
**Scope:** Android Maps key loading only. No signing changes (PR-006). No map UI/runtime Dart changes.

## Rule

`android/app/build.gradle.kts` must **not** contain a hardcoded Maps API key fallback.  
The key is supplied at build time from local or CI configuration.

## Resolution order

1. Gradle property: `-PGOOGLE_MAPS_API_KEY=...` or `gradle.properties` (do not commit secrets)
2. Environment variable: `GOOGLE_MAPS_API_KEY`
3. File: `android/local.properties` → `GOOGLE_MAPS_API_KEY=...`

If none are set, the Android build **fails fast** with a clear error.

## Developer machine

`android/local.properties` is gitignored. Add:

```properties
GOOGLE_MAPS_API_KEY=your_key_here
```

(Flutter/`flutter.sdk` lines already belong in this file.)

## CI / future release pipeline

Inject the secret without committing it, for example:

```bash
export GOOGLE_MAPS_API_KEY="***"
# or
flutter build apk -PGOOGLE_MAPS_API_KEY="***"
```

Store the value in GitHub Actions secrets / Secret Manager — never in git.

## Manifest

`AndroidManifest.xml` continues to use `${GOOGLE_MAPS_API_KEY}` via `manifestPlaceholders`. Behavior is unchanged when the key is provided.

## Residual keys (out of PR-005 scope)

Per Master Execution Plan PR-005 allowed files, **iOS** and **`lib/**` were not modified in this PR.  
The same historical Maps key string may still appear in:

- `ios/Flutter/*.xcconfig`
- `ios/Runner/AppDelegate.swift` (fallback)
- `lib/src/core/config/app_config.dart` (`_mapApiKeyDefault`)

Those require a **separate owned change** (budget/exception or follow-up PR). Rotate/restrict the exposed key in Google Cloud Console regardless.

## Rollback

Temporarily restore a non-secret placeholder + docs only — **do not** re-commit a real API key. Prefer fixing local/CI injection instead.
