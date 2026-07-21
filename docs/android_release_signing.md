# Android Release Signing (PR-006)

**Epic B Safety · RK-062 · EV-144**  
**Scope:** Android release signing configuration only. Maps key handling remains PR-005. No iOS changes.

## Rule

- `release` builds must **not** use the debug keystore.
- Signing material lives outside git: `android/key.properties` + `*.jks` / `*.keystore`.
- `android/.gitignore` already ignores `key.properties`, `**/*.keystore`, `**/*.jks`.

## Local setup

1. Create an upload keystore (once), e.g.:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Copy the example file:

```bash
cp android/key.properties.example android/key.properties
```

3. Edit `android/key.properties` (do not commit):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` is resolved relative to the `android/` directory.

4. Build:

```bash
flutter build appbundle
# or
cd android && ./gradlew :app:bundleRelease -PGOOGLE_MAPS_API_KEY=...
```

## CI / future release pipeline

In CI, write `android/key.properties` and place the keystore from secrets (GitHub Actions secrets / Secret Manager) at the path in `storeFile`. Never echo passwords into logs.

Example (conceptual):

```bash
# decode keystore from base64 secret → android/upload-keystore.jks
cat > android/key.properties <<EOF
storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}
keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
storeFile=upload-keystore.jks
EOF
```

## Behavior summary

| Build type | Signing |
|------------|---------|
| `debug` | AGP default debug keystore |
| `release` with `key.properties` | `signingConfigs.release` |
| `release` without `key.properties` | **Fails** at packaging (`assembleRelease` / `bundleRelease`) — no silent debug fallback |

## Play App Signing

Prefer Google Play App Signing: upload key locally/CI; Play holds the app signing key. First release should go to an **internal** track.

## Rollback

Emergency hotfix only: temporarily re-point release to debug on a documented branch — **not** for production stores. Preferred fix: restore valid `key.properties` + keystore from secure backup.
