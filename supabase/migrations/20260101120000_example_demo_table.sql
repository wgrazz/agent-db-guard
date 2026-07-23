-- Example migration. Replace with your own.
-- Filename must be: YYYYMMDDHHMMSS_snake_case_name.sql

create table if not exists public.agent_db_guard_demo (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now()
);
