#!/usr/bin/env bash
# Validate migration filenames: unique 14-digit UTC timestamp prefixes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ $# -gt 0 && "${1:-}" != "--strict" ]]; then
  echo "Usage: $0 [--strict]" >&2
  exit 2
fi

errors=0
timestamp_count=0
file_list="$(
  find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.sql' -print \
    | LC_ALL=C sort
)"

while IFS= read -r migration_path; do
  [[ -n "$migration_path" ]] || continue
  migration_name="$(basename "$migration_path")"

  if [[ "$migration_name" =~ ^[0-9]{14}_[a-z0-9][a-z0-9_]*\.sql$ ]]; then
    timestamp_count=$((timestamp_count + 1))
  else
    echo "ERROR: invalid migration filename (want YYYYMMDDHHMMSS_name.sql): $migration_name" >&2
    errors=$((errors + 1))
  fi
done <<< "$file_list"

duplicate_rows="$(
  printf '%s\n' "$file_list" \
    | awk -F/ 'NF {
        name=$NF
        split(name, parts, "_")
        count[parts[1]]++
        files[parts[1]]=files[parts[1]] " " name
      }
      END {
        for (version in count)
          if (count[version] > 1)
            print version "|" count[version] "|" files[version]
      }' \
    | LC_ALL=C sort
)"

while IFS='|' read -r version count names; do
  [[ -n "$version" ]] || continue
  echo "ERROR: duplicate migration version $version:$names" >&2
  errors=$((errors + 1))
done <<< "$duplicate_rows"

if (( errors > 0 )); then
  echo "Migration checks failed with $errors error(s)." >&2
  exit 1
fi

echo "Migration checks passed: $timestamp_count timestamped file(s)."
