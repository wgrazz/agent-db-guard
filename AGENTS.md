# Agent Database Rules (agent-db-guard)

Drop this file into any repo that uses Supabase migrations with coding agents
(Claude, Cursor, Copilot, Codex, etc.). If another agent doc conflicts about
database mutations, this file wins.

## Safe without additional approval

- Read migration files and database documentation.
- `npm run db:migrations:check` — local filename checks.
- `npm run db:status` — the linked project's migration history (read-only).
- `npm run db:plan` — linked dry run; does not mutate production.
- `npm run db:query -- <file.sql>` — runs a SQL file only if it contains no writing keyword.
- `npm run db:replay` — replays every migration into a throwaway local Postgres container.
- Report pending migrations, risk findings, and the exact approval code.

## Explicit approval required

- Any hosted database mutation.
- `npm run db:apply -- <approved-plan-code>` only after a human approves that exact code.
- `--allow-destructive` only when the human explicitly acknowledges the listed data/destructive findings.
- `npm run db:setup` (login and link) is for the human. If a guarded command reports missing
  login or link state, stop and report it; never request, read, print or paste tokens or passwords.

## Required workflow

1. Put every schema/function/policy/seed change in `supabase/migrations/` with a unique 14-digit UTC timestamp prefix (`YYYYMMDDHHMMSS_name.sql`).
2. Run `npm run db:migrations:check -- --strict`, `npm run db:status`, then `npm run db:plan`.
3. Show the human the pending list, risk findings, and the approval code. Stop.
4. After they approve that exact code, run `npm run db:apply -- <code>` (add `--allow-destructive` only if they approved the listed risks).
5. If files or remote state change after planning, the code is invalid — re-plan.
6. After an approved apply, run `npm run db:status` and a focused `npm run db:query` for the objects or rows changed, then report the exact result.

Approval is single-plan authorization, not standing permission.

## Never bypass the guard

- Do not run `supabase db push`, linked `supabase migration up`, raw production SQL, seeds, resets, or repair commands to skip this flow.
- Do not use `--include-all`, `--password`, or a database URL on the command line.
- Do not use Dashboard SQL or Table Editor for schema changes; all changes come from committed migration files.
- Treat everything under `supabase/.temp/` as secret machine-local state even though Git ignores it.
- Do not print `.env` contents or access tokens.
