#!/usr/bin/env bash
# Apply pending migrations only if the approval code still matches the plan.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <approved-plan-code> [--allow-destructive]" >&2
  exit 2
fi

approved_code="$1"
allow_destructive=false
if [[ $# -eq 2 ]]; then
  if [[ "$2" != "--allow-destructive" ]]; then
    echo "Unknown option: $2" >&2
    exit 2
  fi
  allow_destructive=true
fi

require_supabase_cli
"$SCRIPT_DIR/check-migrations.sh" --strict

if ! dry_run_output="$(capture_remote_dry_run)"; then
  echo "$dry_run_output" >&2
  exit 1
fi

pending_names=()
while IFS= read -r migration_name; do
  [[ -n "$migration_name" ]] && pending_names+=("$migration_name")
done < <(pending_migrations_from_dry_run "$dry_run_output")

risks=""
if (( ${#pending_names[@]} > 0 )); then
  risks="$(risk_findings "${pending_names[@]}")"
fi
manifest="$(migration_manifest)"
current_code="$(plan_approval_code "$manifest" "$dry_run_output" "$risks")"

if [[ "$approved_code" != "$current_code" ]]; then
  echo "Approval code mismatch. The files or remote migration state changed after review." >&2
  echo "Run npm run db:plan again and obtain new explicit approval." >&2
  exit 1
fi

if [[ -n "$risks" && "$allow_destructive" == false ]]; then
  echo "Potentially destructive or data-changing SQL was detected:" >&2
  echo "$risks" >&2
  echo "A human must explicitly approve these findings before --allow-destructive may be used." >&2
  exit 1
fi

echo "$dry_run_output"
echo
echo "Applying explicitly approved production migration plan $current_code."
cd "$REPO_ROOT"
"$SUPABASE_BIN" db push --linked --yes
"$SUPABASE_BIN" migration list --linked
