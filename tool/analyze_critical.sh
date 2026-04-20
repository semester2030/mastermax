#!/usr/bin/env bash
# فلترة تحليل Dart/Flutter للأخطاء الحرجة (سطور تبدأ بـ error • في مخرجات flutter analyze).
#
#   ./tool/analyze_critical.sh              → تشغيل كامل + ملخص error في النهاية + خروج 1 إن وُجد error
#   ./tool/analyze_critical.sh --errors-only → لا يطبع إلا سطور error • (مناسب للـ CI السريع)
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [[ "${1:-}" == "--errors-only" ]]; then
  set +e
  flutter analyze >"$TMP" 2>&1
  set -e
  if grep -q 'error •' "$TMP"; then
    grep 'error •' "$TMP"
    echo ""
    echo "analyze_critical: وُجدت أخطاء حرجة (exit 1)"
    exit 1
  fi
  echo "analyze_critical: لا توجد أخطاء error •"
  exit 0
fi

set +o pipefail
flutter analyze 2>&1 | tee "$TMP"
set -o pipefail

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ملخص: سطور error • فقط (أخطاء حرجة)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if grep -q 'error •' "$TMP"; then
  grep 'error •' "$TMP"
  echo ""
  echo "→ خروج 1 (يوجد خطأ تحليل حرج). لتجاهل info/warning في CI استخدم:"
  echo "    flutter analyze --no-fatal-infos --no-fatal-warnings"
  exit 1
fi

echo "(لا توجد — المشروع بلا أسطر error • في هذا التشغيل)"
echo ""
echo "→ للـ CI عندما يكفي غياب error فقط:"
echo "    flutter analyze --no-fatal-infos --no-fatal-warnings"
exit 0
