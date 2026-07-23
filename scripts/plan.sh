#!/usr/bin/env bash
# Dry-run pending migrations and print a human-approval code.
# Does not mutate the hosted database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
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
approval_code="$(plan_approval_code "$manifest" "$dry_run_output" "$risks")"

echo "$dry_run_output"
echo
if [[ -n "$risks" ]]; then
  echo "Potentially destructive or data-changing SQL requires separate explicit approval:"
  echo "$risks"
else
  echo "No destructive SQL patterns were detected in the pending migrations."
fi
echo
echo "Approval code: $approval_code"
echo "Production remains unchanged. A human must explicitly approve this exact code before db:apply."
