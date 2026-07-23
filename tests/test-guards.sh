#!/usr/bin/env bash
# Offline tests for approval codes and migration filename checks.
# Does not touch a hosted database.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/common.sh
source "$ROOT/scripts/common.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# --- approval codes are deterministic and content-sensitive ---
sample_dry_run="Would push migration 20260101120000_example.sql"
code_one="$(plan_approval_code "manifest" "$sample_dry_run" "")"
code_two="$(plan_approval_code "manifest" "$sample_dry_run" "")"
code_changed="$(plan_approval_code "changed manifest" "$sample_dry_run" "")"
[[ "$code_one" == "$code_two" ]] || fail "approval codes are not deterministic"
[[ "$code_one" != "$code_changed" ]] || fail "approval code ignored manifest changes"

# --- risk scanner catches destructive SQL ---
cat > "$tmpdir/20260101120000_risky.sql" <<'SQL'
DROP TABLE IF EXISTS public.demo;
SQL
export MIGRATIONS_DIR="$tmpdir"
risks="$(risk_findings "20260101120000_risky.sql")"
echo "$risks" | grep -qi 'drop' || fail "risk_findings missed DROP"

# --- filename check accepts timestamped migrations ---
mkdir -p "$tmpdir/ok"
cp "$tmpdir/20260101120000_risky.sql" "$tmpdir/ok/20260101120000_risky.sql"
export MIGRATIONS_DIR="$tmpdir/ok"
if ! "$ROOT/scripts/check-migrations.sh" --strict >/dev/null; then
  fail "valid timestamped migration rejected"
fi

# --- filename check rejects bad names ---
mkdir -p "$tmpdir/bad"
echo "select 1;" > "$tmpdir/bad/001_legacy.sql"
export MIGRATIONS_DIR="$tmpdir/bad"
if "$ROOT/scripts/check-migrations.sh" --strict >/dev/null 2>&1; then
  fail "legacy three-digit name should fail"
fi

echo "All guard tests passed."
