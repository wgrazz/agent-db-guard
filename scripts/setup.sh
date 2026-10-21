#!/usr/bin/env bash
# Human-only, one time: log in and link the hosted project. Uses the repo-local SUPABASE_HOME
# from common.sh, so the guarded scripts find the same credentials. Agents never run this.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_supabase_cli
cd "$REPO_ROOT"
"$SUPABASE_BIN" login
"$SUPABASE_BIN" link
"$SUPABASE_BIN" migration list --linked
