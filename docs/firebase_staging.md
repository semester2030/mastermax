# Firebase Staging (PR-029)

## Projects

| Alias | Project ID | Role |
|-------|------------|------|
| `default` | `mastermax-2030-backend` | Production (unchanged) |
| `staging` | `mastermax-2030-staging` | Isolated staging |

## App selection

```bash
# Production (default)
flutter run

# Staging
flutter run --dart-define=USE_STAGING=true
```

Same package/bundle IDs as production (no flavor rename in this PR):

- Android: `com.example.mastermax_2030_new`
- iOS: `com.darcar.app`

## Notes

- Native prod files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) are **not** overwritten.
- Reference staging SDK configs (optional, not wired into builds): `config/firebase_staging/`
- Do **not** deploy rules/functions/hosting to staging from this PR.
