#!/usr/bin/env bash
# Build a throwaway database from scratch by replaying every migration against a fresh
# Supabase Postgres container, then leave it running for inspection. Touches nothing hosted.
# Prints the first failing migration and its error. Proves the chain still works end to end,
# which a hosted dry run cannot (it only diffs against what is already applied).
#
#   npm run db:replay                 # container migration-replay stays up
#   docker rm -f migration-replay
#
# Hosted Supabase's storage service owns storage.buckets/objects and its auth service defines
# auth.jwt(); the bare image has neither, so minimal stand-ins are created before the chain runs.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
set +e

C=migration-replay
IMAGE=public.ecr.aws/supabase/postgres:17.6.1.063
PSQL=(docker exec -i "$C" psql -h 127.0.0.1 -d postgres -v ON_ERROR_STOP=1 -q)

docker rm -f "$C" >/dev/null 2>&1
docker run -d --name "$C" -e POSTGRES_PASSWORD=postgres "$IMAGE" >/dev/null || exit 1
for _ in $(seq 1 60); do docker exec "$C" pg_isready -U postgres -h 127.0.0.1 >/dev/null 2>&1 && break; sleep 1; done
sleep 3  # image init scripts finish after pg_isready

"${PSQL[@]}" -U supabase_admin <<'SQL'
CREATE TABLE storage.buckets (id text PRIMARY KEY, name text NOT NULL, owner uuid, public boolean DEFAULT false,
  file_size_limit bigint, allowed_mime_types text[], created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
CREATE TABLE storage.objects (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text REFERENCES storage.buckets(id),
  name text, owner uuid, metadata jsonb, path_tokens text[], created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO anon, authenticated, service_role;
-- Hosted Supabase defines auth.jwt(); the bare image ships only auth.uid()/auth.role().
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim', true), ''),
                  nullif(current_setting('request.jwt.claims', true), ''))::jsonb
$$;
SQL

n=0
while IFS= read -r f; do
  n=$((n+1))
  if ! out=$("${PSQL[@]}" -U postgres -1 <"$f" 2>&1); then
    echo "FAIL #$n $(basename "$f")"; grep -E '^(ERROR|DETAIL|HINT|LINE|psql)' <<<"$out" | head -8; exit 1
  fi
done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -name '*.sql' | LC_ALL=C sort)
echo "OK: $n migrations built a database from scratch (container $C)"
