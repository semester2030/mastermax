# mastermax_2030_new

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Operations

- **Developer runbook (authoritative):** [`docs/ops_runbook.md`](docs/ops_runbook.md) — four app entry points, local run, analyze/test parity with CI.
- **Firestore Disaster Recovery runbook:** [`docs/ops_dr_firestore.md`](docs/ops_dr_firestore.md) — backup strategy, restore workflow, isolated restore drill procedure. No production backup/restore is executed by that document alone.
- **Firestore rules serial queue:** [`docs/ops_rules_queue.md`](docs/ops_rules_queue.md) — process-only merge queue for rules changes.
- **Ownership:** [`.github/CODEOWNERS`](.github/CODEOWNERS)
- **Required CI admin checklist:** [`docs/ci_required.md`](docs/ci_required.md) — branch protection is enabled by repo admins in GitHub Settings (not by YAML alone).

**Required-gate readiness:** [`docs/ci_required.md`](docs/ci_required.md)
