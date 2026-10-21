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
npm run db:setup         # you, once: supabase login + link (agents never run this)
npm run db:migrations:check
npm run db:status        # linked migration history, read-only
npm run db:plan          # dry run + approval code
```

## Commands

| Command | Who | What it does |
| --- | --- | --- |
| `db:setup` | human, once | Log in and link the hosted project. Login state lives in `supabase/.temp/` (gitignored, owner-only), not in `~`, so a sandboxed agent never needs your home directory |
| `db:migrations:check [-- --strict]` | agent | Filename and duplicate-version checks, offline |
| `db:status` | agent | Checks plus `migration list --linked` |
| `db:plan` | agent | Hosted dry run, risk scan, approval code |
| `db:apply -- <code> [--allow-destructive]` | agent, after approval | Push only if the code still matches |
| `db:query -- <file.sql> [--json]` | agent | Run a SQL file against the linked project, refused if it contains any writing keyword. For verifying what an approved apply did |
| `db:replay` | agent | Replay every migration into a fresh `supabase/postgres` Docker container and leave it up. Proves the chain builds from scratch, which a hosted dry run cannot |

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
