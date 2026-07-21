# DAR CAR — Firestore Rules Review Queue

**PR-003 · Epic A Protect · RK-036 / RK-020 (process) · EV-173**  
**Status:** Official process document (governance only — does **not** modify rules)  
**Last updated:** 2026-07-20

Related: [`.github/CODEOWNERS`](../.github/CODEOWNERS) · [ops runbook](ops_runbook.md) · [dev improvement portal](dar_car_dev_improvement_portal.html)

---

## 1. Purpose

Define a **serial review and merge queue** for Firestore (and Storage) security rules so that:

- Every rules change has an explicit owner (CODEOWNERS).
- No Security PR merges without Security Lead approval.
- Rules changes never land in the same PR as unrelated product work.
- Blast radius stays measurable (Change Budget / Zero Exit).

This document is **process only**. It does not add, remove, or rewrite any rule statements.

---

## 2. Why Firestore Rules require serial execution

| Reason | Detail |
|--------|--------|
| Shared global file | `firestore.rules` is one deployment unit for the whole project |
| Cross-surface blast radius | Mobile, Property Web, Car Web, and Admin all depend on the same rules |
| Hard-to-bisect failures | Mixing rules with Dart/Functions in one PR hides the failing change |
| RK-036 / RK-020 | CRM and authz tightening must be reviewable in small, ordered batches (PR-009+) |
| Observe window | Production permission errors need a clean “rules-only” window to attribute |

**Rule:** At most **one open rules PR** in the Security train at a time, unless Security Lead explicitly waives with a written note in the PR.

---

## 3. Sensitive areas (ownership domains)

| Domain | Paths (exist in repo) | Owner role |
|--------|----------------------|------------|
| Firestore Rules | `firestore.rules` | Security Lead |
| Storage Rules | `storage.rules` | Security Lead |
| Indexes | `firestore.indexes.json` | Security Lead (+ Data) |
| Firebase project config | `firebase.json`, `.firebaserc`, `lib/firebase_options.dart` | Security / Infra |
| Cloud Functions | `functions/` | Functions Owner |
| Flutter app | `lib/`, `lib/src/` | Flutter Lead |
| Maps | `lib/src/features/map/`, `lib/src/core/geo/` | Maps Owner |
| Auth | `lib/src/features/auth/` | Auth / Security |
| Admin | `lib/admin_web/` | Admin Owner |
| Storefront / Car Web | `lib/car_web/`, `lib/src/features/storefront/` | Storefront Owner |
| Theme | `lib/src/core/theme/` | Design / Flutter (frozen vs Security) |
| Ads | `lib/src/features/premium_ads/` | Ads (Epic H — separate train) |
| Docs / CI | `docs/`, `.github/` | TPM / Infra |

GitHub enforcement: see `.github/CODEOWNERS`.

---

## 4. Approval workflow

```
1. Author opens a RULES-ONLY PR (see §7 Forbidden combinations)
2. PR description must include:
   - RK / EV IDs
   - Change Budget class (CB-*)
   - Blast Radius (BR-*)
   - Rollback steps
   - Observe plan
3. Soft CI green (when applicable): analyze_critical + flutter test
4. Required reviewer: CODEOWNERS for firestore.rules / storage.rules
   (Security Lead — currently @FAYEZ2030)
5. Human Security review: deny/allow semantics, no drive-by refactors
6. Merge to main/master
7. Observe period (§6)
8. Only then start the next rules PR
```

**Required reviewers for any change to `firestore.rules` or `storage.rules`:**

- CODEOWNERS match for those files (Security Lead)
- Optional second reviewer for CRM batches (PR-009+) if available

Branch protection “required reviews” may be enabled in a later PR; until then this queue is **policy-mandatory**.

---

## 5. Merge order (Security train)

Governance order from Master Execution Plan (do not reorder casually):

1. **PR-003** — this queue + CODEOWNERS (process) ← current  
2. Field inventory / measurement as required by later Security PRs  
3. **PR-009+** — CRM rules tightening batches (RK-036), one batch per PR  
4. Other rules PRs only after prior Observe completes or waiver is recorded  

Non-rules PRs (Flutter, Maps, Ads, Brand) must **not** block or bundle into a rules PR.

---

## 6. Observe period

| Change type | Minimum observe after merge |
|-------------|----------------------------|
| Process / CODEOWNERS only (PR-003) | **0h** |
| Narrow rules batch (single collection group) | **24h** (unless MEP says otherwise) |
| Broad rules change | Follow MEP for that PR ID |

During observe:

- Watch permission-denied spikes (clients + Functions)
- Watch Admin / Car Web / Property Web login and list flows
- Do **not** open the next rules PR until Observe clears or Security Lead waives

---

## 7. Forbidden combinations

Do **not** combine the following in one PR with `firestore.rules` / `storage.rules` changes:

| Forbidden combo | Why |
|-----------------|-----|
| **Rules + Dart (`lib/**`)** | Client and authz change together → cannot tell which broke access |
| **Rules + Functions (`functions/`)** | Server and rules race; dual deploy risk |
| **Rules + Theme (`lib/src/core/theme/`)** | Unrelated blast radius; violates Epic separation |
| **Rules + Ads (`premium_ads` / ads portals)** | Epic H is independent; must not block or hitchhike Security |
| **Rules + Maps (`map` / `geo`)** | Maps PRs have their own secret/key risk domain |
| **Rules + Auth feature code** | Auth UX and rules semantics must be reviewed separately |
| **Rules + Brand / payments / spotlight** | Deferred / protected; out of Security batch scope |
| **Multiple unrelated collection tightenings** | Prefer one CRM batch per PR (PR-009 style) |

Allowed with rules (narrow):

- Docs that describe **this** rules change only  
- Test fixtures **only if** a later PR budget explicitly allows them (not invented here)  
- `firestore.indexes.json` **only when** the same PR’s rules require an index and MEP allows it for that PR ID  

---

## 8. Rollback procedure

1. Revert the rules PR commit (or redeploy previous `firestore.rules` / `storage.rules` from git).  
2. Confirm Firebase Rules deploy matches the reverted file.  
3. Record rollback in the [dev improvement portal](dar_car_dev_improvement_portal.html) execution log.  
4. Do not “hotfix” by mixing a rules revert with a large Dart PR.

For **this** PR-003 (process only): delete/revert `.github/CODEOWNERS` and `docs/ops_rules_queue.md` — no Firebase deploy required.

---

## 9. Queue checklist (copy into Rules PRs)

- [ ] PR touches rules files only (plus allowed docs/indexes per MEP for that PR)  
- [ ] No Dart / Functions / Theme / Ads / Maps / Auth feature code in the same PR  
- [ ] CODEOWNERS Security Lead reviewed  
- [ ] RK / EV / CB / BR cited  
- [ ] Rollback steps written  
- [ ] Observe window planned  
- [ ] Previous rules PR Observe complete (or waiver linked)  

---

## 10. Explicit non-goals (PR-003)

- No edits to `firestore.rules` or `storage.rules` content  
- No new allow/deny logic  
- No optimization or cleanup of rules  
- No business-logic audit of CRM collections  

Those belong to later Security PRs after this queue is in place.
