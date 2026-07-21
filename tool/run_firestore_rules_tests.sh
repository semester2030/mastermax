#!/usr/bin/env bash
# PR-028 — Run all Firestore rules unit tests against the Firestore Emulator.
# Does not deploy. Does not modify repo firebase.json.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT/test/firestore_rules"

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "ERROR: missing $TESTS_DIR" >&2
  exit 1
fi

shopt -s nullglob
TESTS=( "$TESTS_DIR"/*.test.js )
shopt -u nullglob

if [[ ${#TESTS[@]} -eq 0 ]]; then
  echo "ERROR: no *.test.js under $TESTS_DIR" >&2
  exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/darcar-rules-XXXXXX")"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$WORKDIR/firebase.json" <<'EOF'
{
  "emulators": {
    "firestore": {
      "host": "127.0.0.1",
      "port": 8080
    }
  }
}
EOF

# Ephemeral runner invoked inside emulators:exec (keeps repo firebase.json untouched).
{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  echo "export NODE_PATH=\"$WORKDIR/node_modules\${NODE_PATH:+:\$NODE_PATH}\""
  echo 'echo "Running Firestore rules tests..."'
  for f in "${TESTS[@]}"; do
    printf 'echo "=== %s ==="\n' "$(basename "$f")"
    printf 'node %q\n' "$f"
  done
  echo 'echo "Firestore Rules Emulator Tests: ALL PASSED"'
} > "$WORKDIR/run_tests.sh"
chmod +x "$WORKDIR/run_tests.sh"

cd "$WORKDIR"
npm init -y >/dev/null 2>&1
npm install --no-fund --no-audit @firebase/rules-unit-testing firebase firebase-admin >/dev/null

echo "Starting Firestore Emulator and running ${#TESTS[@]} rules test file(s)..."
npx --yes firebase-tools@13 emulators:exec \
  --only firestore \
  --project demo-darcar-rules-ci \
  --config "$WORKDIR/firebase.json" \
  "bash $WORKDIR/run_tests.sh"
