#!/usr/bin/env bash
# Run a SQL file against the linked project, but only if it is read-only.
# Lets agents verify what an approved migration did without a path to mutate anything.
# Usage: query.sh path/to/checks.sql [--json]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ $# -lt 1 || $# -gt 2 || ( $# -eq 2 && "$2" != "--json" ) ]]; then
  echo "Usage: $0 <file.sql> [--json]" >&2
  exit 2
fi
sql_file="$1"
output_args=()
[[ $# -eq 2 ]] && output_args=(--output-format json)

# Keyword blocklist, deliberately blunt: a comment that says "create" is refused too.
# Rewrite the comment; do not loosen the pattern.
if grep -Eiq '(^|[^a-z])(insert|update|delete|merge|alter|create|drop|truncate|grant|revoke|call|do|copy|vacuum|reindex|cluster|refresh|comment|security)[[:space:]]' "$sql_file"; then
  echo "Refusing to run: $sql_file contains a non-read-only SQL keyword." >&2
  exit 1
fi

require_supabase_cli
cd "$REPO_ROOT"
"$SUPABASE_BIN" db query --linked --file "$sql_file" "${output_args[@]+"${output_args[@]}"}" --agent no
