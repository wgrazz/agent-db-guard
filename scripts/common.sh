#!/usr/bin/env bash
# Shared helpers for approval-gated Supabase migrations.

set -euo pipefail

GUARD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$GUARD_SCRIPT_DIR/.." && pwd)"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-$REPO_ROOT/supabase/migrations}"

# Prefer local install, then PATH.
resolve_supabase_cli() {
  if [[ -x "$REPO_ROOT/node_modules/.bin/supabase" ]]; then
    echo "$REPO_ROOT/node_modules/.bin/supabase"
  elif command -v supabase >/dev/null 2>&1; then
    command -v supabase
  else
    echo ""
  fi
}

require_supabase_cli() {
  local bin
  bin="$(resolve_supabase_cli)"
  if [[ -z "$bin" ]]; then
    echo "Supabase CLI not found. Install it (npm i -D supabase) or put supabase on PATH." >&2
    exit 1
  fi
  SUPABASE_BIN="$bin"
}

migration_manifest() {
  (
    cd "$REPO_ROOT"
    find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.sql' -print \
      | LC_ALL=C sort \
      | while IFS= read -r migration_file; do
          migration_hash="$(shasum -a 256 "$migration_file" | awk '{print $1}')"
          printf '%s  %s\n' "$migration_hash" "$migration_file"
        done
  )
}

guard_manifest() {
  local guard_path
  local guard_hash
  local guard_files=(
    scripts/common.sh
    scripts/check-migrations.sh
    scripts/plan.sh
    scripts/apply.sh
  )

  (
    cd "$REPO_ROOT"
    for guard_path in "${guard_files[@]}"; do
      guard_hash="$(shasum -a 256 "$guard_path" | awk '{print $1}')"
      printf '%s  %s\n' "$guard_hash" "$guard_path"
    done
  )
}

capture_remote_dry_run() {
  local output
  local status

  set +e
  output="$(cd "$REPO_ROOT" && "$SUPABASE_BIN" db push --linked --dry-run 2>&1)"
  status=$?
  set -e

  printf '%s\n' "$output"
  return "$status"
}

pending_migrations_from_dry_run() {
  local dry_run_output="$1"

  printf '%s\n' "$dry_run_output" \
    | grep -E 'Would push migration|^[[:space:]]*•[[:space:]]+[0-9]' \
    | grep -Eo '[0-9]{14}_[a-zA-Z0-9_]+\.sql' \
    | LC_ALL=C sort -u \
    || true
}

risk_findings() {
  local migration_name
  local migration_path

  for migration_name in "$@"; do
    migration_path="$MIGRATIONS_DIR/$migration_name"
    if [[ ! -f "$migration_path" ]]; then
      echo "Dry run named a migration that is not present locally: $migration_name" >&2
      return 1
    fi

    grep -HEni \
      '^[[:space:]]*(drop[[:space:]]|truncate[[:space:]]|delete[[:space:]]+from[[:space:]]|update[[:space:]].*[[:space:]]set[[:space:]]|insert[[:space:]]+into[[:space:]]|revoke[[:space:]])' \
      "$migration_path" \
      || true
  done
}

plan_approval_code() {
  local manifest="$1"
  local dry_run_output="$2"
  local risks="$3"

  local guards
  guards="$(guard_manifest)"

  printf '%s\n-- guard scripts --\n%s\n-- dry run --\n%s\n-- risks --\n%s\n' \
    "$manifest" "$guards" "$dry_run_output" "$risks" \
    | shasum -a 256 \
    | awk '{print $1}'
}
