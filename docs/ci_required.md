# DAR CAR — Required CI Gate (PR-008)

**Epic B Safety · RK-060 · EV-140**  
**Status:** Repository ready for required CI · branch protection is a **GitHub Settings** action  
**Date:** 2026-07-21

---

## 1. Distinction: repo vs GitHub org/settings

| Layer | What it is | Who changes it | This PR |
|-------|------------|----------------|---------|
| **Repository configuration** | `.github/workflows/ci.yml` workflow file in git | Developers via PR | Updated here |
| **GitHub organization / repo Settings** | Branch protection rules, required status checks | Repo **Admin** in GitHub UI / API | **Documented only — not applied by this PR** |

This PR does **not** fake branch protection. Enabling “required checks” cannot be done by committing YAML alone.

---

## 2. Current CI workflow (repository)

| Field | Value |
|-------|--------|
| File | `.github/workflows/ci.yml` |
| Workflow `name` | `CI` |
| Job id | `analyze-and-test` |
| **Required check display name** | `Analyze critical + Flutter tests` |
| Triggers | `pull_request` · `push` to `main` / `master` |
| Steps | `flutter pub get` → `bash tool/analyze_critical.sh` → `flutter test` |
| Flutter | `3.38.9` stable |

History: PR-001 introduced Soft (visibility) CI. PR-008 renames/labels it as the gate to require after stability.

---

## 3. Admin checklist — enable required CI (manual)

In GitHub: **Settings → Branches → Branch protection rules** (or Rulesets) for `main` and `master` (if used):

1. **Require a pull request before merging** — recommended  
2. **Require status checks to pass before merging** — **ON**  
3. **Require branches to be up to date before merging** — recommended once CI is green  
4. Add required check exactly named:  
   **`Analyze critical + Flutter tests`**  
5. Do **not** require checks that do not exist  
6. Optionally: require CODEOWNERS review (`.github/CODEOWNERS` already present from PR-003)

### After first successful Actions run

Status check names appear in the protection UI only after the workflow has run at least once on the default branch / a PR. If the check is missing from the dropdown:

1. Merge/push so Actions runs  
2. Re-open the branch protection editor  
3. Select `Analyze critical + Flutter tests`

### Confirmation

- [ ] Workflow visible under Actions  
- [ ] Check name matches exactly  
- [ ] A test PR cannot merge while the check is failing  
- [ ] A green PR can merge (with other rules satisfied)

---

## 4. Local parity (same commands as CI)

```bash
flutter pub get
bash tool/analyze_critical.sh
flutter test
```

---

## 5. Rollback

| Layer | Rollback |
|-------|----------|
| Workflow file | Revert `.github/workflows/ci.yml` |
| Branch protection | Admin: remove required check / set optional (GitHub Settings) |

Do not disable CI entirely without TPM approval before Security train (PR-009+).

---

## 6. Known limitations

- `gh` may report no workflows until this file is pushed to GitHub.  
- Branch protection API/UI requires admin rights.  
- Flaky tests block merges once required — fix flakes before enabling (MEP).  
- Expanding test scope is **out of PR-008** (MEP: no test expansion in this PR).
