# DAR CAR — Firestore Disaster Recovery Runbook

**PR-007 · Epic B Safety · RK-061 · EV-150 · EV-151 · EV-171**  
**Status:** Official operations documentation (preparation only)  
**Date:** 2026-07-21  
**Production Firebase project (config evidence):** `mastermax-2030-backend` (`.firebaserc`)

---

## Explicit statements (Zero Exit)

- This PR **documents** DR procedures only.
- **No** backup job was created in this PR.
- **No** backup was executed in this PR.
- **No** restore was executed in this PR.
- **No** Google Cloud / Firebase Console settings were changed.
- **No** application runtime, rules, or Functions were modified.

---

## 1. Purpose

Provide a single, reviewable runbook so DAR CAR can:

1. Define recovery objectives (RPO / RTO targets).
2. Enable and operate Firestore backups (ops action — outside this PR).
3. Practice restore **only** into an isolated project.
4. Avoid catastrophic overwrite of production data.

Evidence gap closed by this document: EV-150 (no backup schedule/runbook in repo), RK-061 (no practiced/documented restore). Media (EV-151) and Hosting rollback (EV-171) are noted as related but out of this file’s primary scope.

---

## 2. Recovery objectives

| Objective | Target (planning) | Notes |
|-----------|-------------------|--------|
| **RPO** (max acceptable data loss) | ≤ 24 hours | Align with daily scheduled export / managed backup cadence once enabled |
| **RTO** (max time to recover service) | ≤ 8 hours (Conditional) · tighten before Commercial GO | Depends on index rebuild, app config, and validation |
| **Scope** | Firestore `(default)` database for `mastermax-2030-backend` | Hosting/Functions/media have separate tracks |

Targets above are **policy placeholders** until a real drill fills measured values in §12.

---

## 3. Supported backup strategy

### 3.1 Recommended (ops — not executed here)

| Layer | Approach | Owner |
|-------|----------|--------|
| **A — Managed** | Google Cloud Firestore scheduled backups / PITR (if enabled for the project) | Infra |
| **B — Export** | Periodic `gcloud firestore export` to a dedicated GCS bucket (versioned, restricted IAM) | Infra |
| **C — Rules/indexes in git** | `firestore.rules`, `firestore.indexes.json` already in repo | Security / Infra |

This repository still has **no** terraform/CI workflow that creates those schedules (EV-150). Enabling A/B is an **Ops Console / Cloud** action with Infra approval — **not** part of PR-007 code.

### 3.2 What is already recoverable from git

| Artifact | Path | Recoverable without Firestore backup? |
|----------|------|----------------------------------------|
| Security rules | `firestore.rules` | Yes (redeploy) |
| Indexes definition | `firestore.indexes.json` | Yes (redeploy; build time applies) |
| Firebase project id | `.firebaserc` → `mastermax-2030-backend` | Identity only |
| Hosting targets | `firebase.json` | Config only (EV-171: no automated rollback workflow yet) |

### 3.3 Out of scope for this runbook (related)

| Asset | Evidence | Follow-up |
|-------|----------|-----------|
| Cloudflare media | EV-151 | Separate media DR runbook |
| Hosting three targets | EV-171 | Deploy/rollback playbook later |
| Auth users / Secret Manager | — | Identity platform procedures |

---

## 4. Safety rules (mandatory)

1. **Never restore directly into production** (`mastermax-2030-backend`) without **written** approval from Infra Owner + Security Lead + TPM.
2. **All restore drills** run only against an **isolated** Firebase/GCP project (staging / scratch), never the live default project.
3. Do not delete production collections “to make room” for a restore.
4. Do not run experimental Console imports on production.
5. Treat any prod restore as a **change window** with rollback plan and customer communication.
6. Keep backup GCS buckets **private**; no public ACLs; least-privilege IAM.
7. Record every drill in §12 and in the [dev improvement portal](dar_car_dev_improvement_portal.html) execution log.

---

## 5. Recovery workflow (incident)

```
1. Detect / declare incident (data loss, corruption, bad write storm)
2. Freeze risky writes if possible (feature flags / maintenance — separate PR ownership)
3. Identify last known good backup / export timestamp
4. Decide: repair in place vs restore-to-isolated then selective copy
5. Obtain approvals (§4)
6. Execute restore path (§6) — isolated first unless approved prod emergency
7. Verify (§7)
8. Re-open traffic
9. Postmortem + lessons (§12)
```

---

## 6. Restore workflow

### 6.1 Isolated drill (required practice — Ops executes later)

1. Create or select an **isolated** Firebase/GCP project for the drill. Preferred options (Infra chooses one):
   - Dedicated scratch: `darcar-dr-scratch` (name placeholder — create when needed), **or**
   - Existing staging: `mastermax-2030-staging` (`.firebaserc` alias `staging`, PR-029) — **only** if treated as disposable for the drill window.
2. Ensure empty or disposable Firestore database in that project.
3. Import/restore from chosen backup/export into the **isolated** project only (**never** `mastermax-2030-backend`).
4. Deploy matching `firestore.rules` / indexes from the git tag used at backup time (or current if intentionally testing forward-compat).
5. Spot-check collections: `cars`, `properties`, `users` (sample docs), CRM collections as needed.
6. Compare document counts / hashes against backup manifest (ops tooling).
7. **Destroy or quarantine** scratch/staging drill data after the exercise; do not promote drill data → prod without a separate approved migration plan.

**PR-007 scope:** this section **documents** the drill. No restore was executed in this PR (`§12` remains `NO_DRILL_YET` until Ops runs one).

### 6.2 Production restore (emergency only)

1. Written approval recorded (ticket + portal note).
2. Announce maintenance / freeze window.
3. Prefer: restore to isolated → validate → selective replay, over full prod overwrite.
4. If full prod restore is unavoidable: follow Cloud Firestore restore docs for the product in use (managed backup vs import), with dual-operator check.
5. Rebuild indexes; redeploy rules from known-good git tag.
6. Run verification checklist (§8).
7. Unfreeze.

---

## 7. Verification steps

| # | Check | Pass criteria |
|---|-------|----------------|
| V1 | Project id | Confirmed isolated vs prod |
| V2 | Backup identity | Timestamp / backup id recorded |
| V3 | Sample reads | Spot checks on core collections succeed |
| V4 | Counts | Order-of-magnitude match to pre-incident / manifest |
| V5 | Rules | `firestore.rules` version matched to intended tag |
| V6 | Indexes | No critical QUERY_REQUIRES_INDEX on smoke paths |
| V7 | Auth | Login smoke on one client surface |
| V8 | Map list smoke | Cars/properties load (no write tests required) |

---

## 8. Recovery checklist (copy into incident ticket)

- [ ] Incident severity and RPO/RTO impact stated  
- [ ] Approvers named (Infra / Security / TPM)  
- [ ] Target project confirmed (**isolated** unless emergency prod approval)  
- [ ] Backup source identified (id / GCS path / timestamp)  
- [ ] Git tag for rules/indexes recorded  
- [ ] Restore executed by dual control (operator + watcher)  
- [ ] Verification V1–V8 completed  
- [ ] Portal / runbook §12 updated  
- [ ] Customer/comms owner notified if prod  

---

## 9. Owner placeholders / contacts

| Role | Responsibility | Name / handle (fill) |
|------|----------------|----------------------|
| Infra Owner | Backups, GCS, restore execution | `MEASUREMENT_REQUIRED` / `@FAYEZ2030` interim |
| Security Lead | Approve prod restore; rules tag | `MEASUREMENT_REQUIRED` |
| TPM | Change window / Conditional GO gate | `MEASUREMENT_REQUIRED` |
| On-call | First response | `MEASUREMENT_REQUIRED` (EV-150: no on-call yet) |

---

## 10. Known limitations

- No scheduled backup automation exists **in this repository** today (EV-150).
- No practiced restore evidence was attached in prior audits (RK-061 / EV-175).
- Single production project increases blast radius — isolated scratch is mandatory for drills.
- Media (Cloudflare) and Hosting rollback are **not** covered end-to-end here (EV-151 / EV-171).
- This document does **not** enable PITR or create GCS buckets by itself.

---

## 11. Rollback (of this documentation PR)

Revert/delete `docs/ops_dr_firestore.md` and any README pointer.  
No Firebase or application rollback required.

---

## 12. Lessons learned (fill after each drill)

| Date (UTC) | Drill type | Project | Backup id | Result | RPO/RTO measured | Notes |
|------------|------------|---------|-----------|--------|------------------|-------|
| — | — | — | — | **NO_DRILL_YET** | — | PR-007 documentation only |

---

## 13. Ops enablement backlog (not this PR)

1. Enable managed Firestore backups and/or daily export to GCS (Infra).  
2. Create isolated `darcar-dr-scratch` **or** schedule a controlled drill on `mastermax-2030-staging` (disposable window).  
3. Run **one** documented restore drill; fill §12.  
4. Add media DR runbook (EV-151).  
5. Add Hosting rollback notes (EV-171).  

**Forbidden in PR-007 and in casual ops:** restore into `mastermax-2030-backend` without §4 approvals.  
**PR-007 executed:** documentation only — **no** backup/restore against production or staging.
