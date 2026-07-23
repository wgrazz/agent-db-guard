# agent-db-guard

Stop coding agents from applying random SQL to production.

Agents can **plan** migrations freely. Applying requires a human to paste an
**approval code** that hashes the migration files + dry-run + risk scan. If
anything changes after review, the code no longer matches and apply refuses.

```
npm run db:plan
# → shows dry-run + risks + Approval code: abc123...

# human: "yes, apply abc123"

npm run db:apply -- abc123
# destructive SQL also needs: --allow-destructive
```

## Why this exists

Coding agents are great at writing migrations and terrible at knowing when
production is sacred. Standing permission ("you can push DB changes") is how
accidents happen. Single-plan authorization fixes that: one code, one apply,
then re-approve next time.

## Install into your repo

1. Copy `scripts/` into your project (or vendor this folder as a submodule).
2. Add npm scripts (see `package.json`).
3. Keep migrations in `supabase/migrations/` named `YYYYMMDDHHMMSS_name.sql`.
4. Drop `AGENTS.md` (or merge its rules) so every agent follows the same gate.
5. Link Supabase once yourself (`npx supabase link`) — agents never get passwords.

```bash
npm install
npm test                 # offline unit tests
npm run db:migrations:check
npm run db:plan          # needs linked project
```

## What gets hashed into the approval code

- SHA-256 of every local `*.sql` migration
- SHA-256 of the guard scripts themselves (so agents can't quietly weaken the gate)
- The dry-run output from `supabase db push --linked --dry-run`
- Detected risk lines (`DROP`, `TRUNCATE`, `DELETE`, `UPDATE…SET`, `INSERT`, `REVOKE`)

## Requirements

- Node 18+
- Supabase CLI (local `devDependency` or on `PATH`)
- A linked Supabase project for `db:plan` / `db:apply`

## License

MIT
