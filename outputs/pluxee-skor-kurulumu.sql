begin;

create table if not exists public.pluxee_runs (
  run_id uuid primary key,
  player_name text not null check (char_length(player_name) between 1 and 32),
  hero text not null check (hero in ('female', 'male')),
  logos integer not null check (logos between 0 and 8),
  correct_doors integer not null check (correct_doors between 0 and 3),
  wrong_doors integer not null check (wrong_doors between 0 and 2),
  seconds_left integer not null check (seconds_left between 0 and 60),
  lives_left integer not null check (lives_left between 0 and 4),
  finish_reason text not null check (finish_reason in ('cleared', 'timeout', 'no_lives')),
  logo_points integer generated always as (logos * 100) stored,
  door_points integer generated always as (correct_doors * 75 - wrong_doors * 25) stored,
  time_points integer generated always as (case when logos = 8 then seconds_left * 15 else 0 end) stored,
  life_points integer generated always as (lives_left * 50) stored,
  total_points integer generated always as (
    logos * 100 + correct_doors * 75 - wrong_doors * 25 +
    case when logos = 8 then seconds_left * 15 else 0 end + lives_left * 50
  ) stored,
  played_at timestamptz not null default now(),
  check (
    (finish_reason = 'cleared' and logos = 8 and lives_left > 0)
    or (finish_reason = 'timeout' and logos < 8 and seconds_left = 0 and lives_left > 0)
    or (finish_reason = 'no_lives' and logos < 8 and lives_left = 0)
  )
);

alter table public.pluxee_runs enable row level security;
revoke all on public.pluxee_runs from public, anon, authenticated;
create index if not exists pluxee_runs_leaderboard_idx
  on public.pluxee_runs (total_points desc, played_at asc, run_id asc);

create or replace function public.pluxee_submit_run(
  p_run_id uuid, p_player_name text, p_hero text, p_logos integer,
  p_correct_doors integer, p_wrong_doors integer, p_seconds_left integer,
  p_lives_left integer, p_finish_reason text
) returns void
language sql security definer set search_path = ''
as $$
  insert into public.pluxee_runs (
    run_id, player_name, hero, logos, correct_doors, wrong_doors,
    seconds_left, lives_left, finish_reason
  ) values (
    p_run_id, coalesce(nullif(btrim(p_player_name), ''), 'Pluxee Kahramanı'),
    p_hero, p_logos, p_correct_doors, p_wrong_doors, p_seconds_left,
    p_lives_left, p_finish_reason
  ) on conflict (run_id) do nothing;
$$;

create or replace function public.pluxee_leaderboard()
returns table (name text, points integer)
language sql stable security definer set search_path = ''
as $$
  select player_name, total_points
  from public.pluxee_runs
  order by total_points desc, played_at asc, run_id asc
  limit 10;
$$;

revoke all on function public.pluxee_submit_run(uuid,text,text,integer,integer,integer,integer,integer,text)
  from public, anon, authenticated;
revoke all on function public.pluxee_leaderboard() from public, anon, authenticated;
grant execute on function public.pluxee_submit_run(uuid,text,text,integer,integer,integer,integer,integer,text)
  to anon, authenticated;
grant execute on function public.pluxee_leaderboard() to anon, authenticated;

commit;
