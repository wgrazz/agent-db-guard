# Agent Database Rules (agent-db-guard)

Drop this file into any repo that uses Supabase migrations with coding agents
(Claude, Cursor, Copilot, Codex, etc.). If another agent doc conflicts about
database mutations, this file wins.

## Safe without additional approval

- Read migration files and database documentation.
- Run `npm run db:migrations:check`.
- Run `npm run db:plan` (linked dry-run only — does not mutate production).
- Report pending migrations, risk findings, and the exact approval code.

## Explicit approval required

- Any hosted database mutation.
- `npm run db:apply -- <approved-plan-code>` only after a human approves that exact code.
- `--allow-destructive` only when the human explicitly acknowledges listed data/destructive findings.
- Linking a project, printing secrets, or pasting database passwords — never do these in chat.

## Required workflow

1. Put every schema/function/policy/seed change in `supabase/migrations/` with a unique 14-digit UTC timestamp prefix (`YYYYMMDDHHMMSS_name.sql`).
2. Run `npm run db:migrations:check -- --strict`, then `npm run db:plan`.
3. Show the human the pending list, risk findings, and the approval code. Stop.
4. After they approve that exact code, run `npm run db:apply -- <code>` (add `--allow-destructive` only if they approved the listed risks).
5. If files or remote state change after planning, the code is invalid — re-plan.

## Never bypass the guard

- Do not run `supabase db push`, raw production SQL, or Dashboard SQL/Table Editor to skip this flow.
- Do not use `--password` or a database URL on the command line.
- Do not print `.env` contents or access tokens.
