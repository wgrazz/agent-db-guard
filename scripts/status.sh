#!/usr/bin/env bash
# Read-only: local filename checks, then the linked project's migration history.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi
require_supabase_cli
"$SCRIPT_DIR/check-migrations.sh"
cd "$REPO_ROOT"
"$SUPABASE_BIN" migration list --linked
