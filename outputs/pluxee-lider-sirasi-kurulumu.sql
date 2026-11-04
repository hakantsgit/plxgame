begin;

create or replace function public.pluxee_run_rank(p_run_id uuid)
returns bigint
language sql stable security definer set search_path = ''
as $$
  select 1 + (
    select count(*)
    from public.pluxee_runs as other
    where other.total_points > current_run.total_points
       or (other.total_points = current_run.total_points
           and (other.played_at, other.run_id) < (current_run.played_at, current_run.run_id))
  )
  from public.pluxee_runs as current_run
  where current_run.run_id = p_run_id;
$$;

revoke all on function public.pluxee_run_rank(uuid) from public, anon, authenticated;
grant execute on function public.pluxee_run_rank(uuid) to anon, authenticated;

commit;
