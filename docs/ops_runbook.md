# DAR CAR — Developer Operations Runbook

**PR-002 · Epic A Protect · RK-056 · EV-132/133/134**  
**Status:** Official developer runbook (documentation only)  
**Last updated:** 2026-07-20

This runbook documents **entry points that exist in the repository**. It does not invent flavors or apps.

---

## 1. Repository overview

| Item | Value (evidence) |
|------|------------------|
| Package name | `mastermax_2030` (`pubspec.yaml`) |
| App version | `7.1.0+10` (`pubspec.yaml`) |
| Dart SDK constraint | `>=3.0.6 <4.0.0` |
| State management | `provider` |
| Backend | Firebase project referenced as `mastermax-2030-backend` (see `firebase.json` / `lib/firebase_options.dart`) |
| Soft CI | `.github/workflows/ci.yml` (PR-001) — `flutter test` + `tool/analyze_critical.sh` |

DAR CAR is a **multi-entry Flutter monorepo**: one codebase, four application entry points.

---

## 2. Folder structure (high level)

```
mastermax/
├── lib/
│   ├── main.dart                 # Mobile consumer app
│   ├── web/web_main.dart         # Property / real-estate web
│   ├── car_web/car_web_main.dart # Car dealer web / CRM
│   ├── admin_web/admin_main.dart # Admin panel web
│   ├── firebase_options.dart
│   └── src/features/…            # Shared feature modules
├── android/ · ios/ · web/        # Platform runners
├── functions/                    # Cloud Functions
├── tool/analyze_critical.sh      # Critical analyzer filter (CI)
├── .github/workflows/ci.yml      # Soft CI
├── .vscode/launch.json           # VS Code launch targets (this PR)
├── docs/                         # Governance portals + this runbook
├── firestore.rules · storage.rules · firebase.json
└── pubspec.yaml
```

---

## 3. Prerequisites

- **Flutter SDK** compatible with `sdk: '>=3.0.6 <4.0.0'`
  - Local project evidence (unpinned FVM): Flutter **3.38.9** stable was used for PR-001 CI pin
  - Prefer matching that version locally until an official FVM pin exists
- **Xcode** (for iOS) / **Android Studio / SDK** (for Android) as needed
- **Chrome** (or another Flutter web device) for web entry points
- **Firebase**: apps expect Firebase initialization via `lib/firebase_options.dart` and platform config files already in the repo (`GoogleService-Info.plist`, `google-services.json`, etc.)
- Do **not** retarget the Firebase project casually (protected component — Phase 0.5)

---

## 4. Install & dependencies

From the **repository root**:

```bash
flutter --version
flutter pub get
```

Do not upgrade Flutter or dependencies as part of routine onboarding unless a separate owned PR authorizes it.

---

## 5. Application entry points (exist in repo)

| # | Application | Entry file | Typical device | Notes |
|---|-------------|------------|----------------|-------|
| 1 | **Mobile (consumer)** | `lib/main.dart` | iOS / Android / simulator | Default Flutter target if `-t` omitted |
| 2 | **Property web** | `lib/web/web_main.dart` | Chrome (`-d chrome`) | Real-estate web surface |
| 3 | **Car web** | `lib/car_web/car_web_main.dart` | Chrome | Dealer / car CRM web |
| 4 | **Admin web** | `lib/admin_web/admin_main.dart` | Chrome | Privileged admin UI — separate entry |

### Flavors

**No Android/iOS product flavors** (`--flavor`) were found in the repository at the time of this runbook.

VS Code / Flutter **modes** that exist for any target:

- `debug` (default)
- `profile`
- `release`

Documented in `.vscode/launch.json` for the **mobile** entry only (profile/release). Web targets use debug via Chrome unless you change `flutterMode` locally.

---

## 6. How to launch each application

### 6.1 Mobile

```bash
flutter run -t lib/main.dart
# or simply:
flutter run
```

### 6.2 Property web

```bash
flutter run -t lib/web/web_main.dart -d chrome
```

### 6.3 Car web

```bash
flutter run -t lib/car_web/car_web_main.dart -d chrome
```

### 6.4 Admin web

```bash
flutter run -t lib/admin_web/admin_main.dart -d chrome
```

### 6.5 VS Code

Open the Run and Debug panel and choose one of:

- `DAR CAR · Mobile (lib/main.dart)`
- `DAR CAR · Mobile (profile)`
- `DAR CAR · Mobile (release)`
- `DAR CAR · Property Web (lib/web/web_main.dart)`
- `DAR CAR · Car Web (lib/car_web/car_web_main.dart)`
- `DAR CAR · Admin Web (lib/admin_web/admin_main.dart)`

---

## 7. Hosting build outputs (reference only)

`firebase.json` defines hosting targets and output folders (do **not** deploy from this PR):

| Hosting target | Public folder | Typical entry for build |
|----------------|---------------|-------------------------|
| `admin` | `build/web-admin` | `-t lib/admin_web/admin_main.dart` |
| `realestate` | `build/web-realestate` | `-t lib/web/web_main.dart` |
| `car` | `build/web-car` | `-t lib/car_web/car_web_main.dart` |

Example build pattern (documentation only):

```bash
flutter build web -t lib/admin_web/admin_main.dart -o build/web-admin
flutter build web -t lib/web/web_main.dart -o build/web-realestate
flutter build web -t lib/car_web/car_web_main.dart -o build/web-car
```

Deploying Firebase Hosting is **out of scope** for day-to-day developer launch and for PR-002.

---

## 8. Common launch mistakes

| Mistake | Why it is wrong | Correct action |
|---------|-----------------|----------------|
| Running default `flutter run` when you meant Admin | Starts **mobile** `lib/main.dart` | Use `-t lib/admin_web/admin_main.dart` |
| Launching Admin on a phone device | Admin is a **web** entry | Use `-d chrome` (or a web device) |
| Mixing Car Web and Property Web | Different CRM surfaces | Confirm `-t lib/car_web/...` vs `-t lib/web/...` |
| Assuming product flavors exist | None found in repo | Use entry `-t` + optional `flutterMode` only |
| Editing `firestore.rules` to “test locally” | Protected / serial Security train | Follow Master Plan; never casual rules edits |
| Enabling camera / payments / WhatsApp flags | Intentionally deferred (Phase 0.5) | Leave flags as-is |

---

## 9. Analyzer & tests

```bash
# Critical errors only (used by Soft CI)
bash tool/analyze_critical.sh

# Full test suite (used by Soft CI)
flutter test
```

Soft CI workflow: `.github/workflows/ci.yml`  
Governance: Soft / non-required until PR-008.

---

## 10. CI overview

| Item | Detail |
|------|--------|
| Workflow | Soft CI |
| Triggers | `pull_request`, `push` to `main` / `master` |
| Steps | `flutter pub get` → `bash tool/analyze_critical.sh` → `flutter test` |
| Flutter in CI | `3.38.9` (pinned in workflow; repo has no FVM pin) |
| Branch protection | Not added by PR-001; remains soft |

---

## 11. Known limitations

- Flutter version is **not** pinned via FVM in the repository.
- `AppConfig.isDevelopmentMode` and other flags may differ from store builds — do not change flags in this PR.
- Multi-entry apps share `lib/src` — a wrong entry can still load shared code; always verify the **entry file**.
- Deferred features (Spotlight Camera, Payments, Billing, WhatsApp live, etc.) remain intentionally disabled — not defects.

---

## 12. Rollback

If this documentation or launch config causes confusion:

1. Revert the PR-002 commit, **or**
2. Restore previous `README.md`, delete `docs/ops_runbook.md`, restore prior `.vscode/launch.json`

No application runtime rollback is required (documentation + launch config only).

---

## 13. Related governance portals

- [تطوير وتحسين دار كار](dar_car_dev_improvement_portal.html) — SSOT + execution log  
- [Master Execution Plan](dar_car_master_execution_plan_portal.html)  
- [Phase 0.5 Scope](dar_car_phase05_portal.html)  
- [MEP v1.2 Budget / Success](dar_car_mep_v12_portal.html)  
