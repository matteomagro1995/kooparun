-- Run this once in Supabase: Project → SQL Editor → New query → Run.
-- It stores a display name, anonymous player ID, and each player's best distance.

create table if not exists public.koopa_leaderboard (
  player_id uuid primary key,
  display_name text not null check (char_length(display_name) between 1 and 18),
  best_distance integer not null check (best_distance >= 0),
  updated_at timestamptz not null default now()
);

alter table public.koopa_leaderboard enable row level security;

create or replace function public.submit_koopa_score(p_player_id uuid, p_display_name text, p_distance integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into koopa_leaderboard (player_id, display_name, best_distance, updated_at)
  values (p_player_id, left(trim(p_display_name), 18), greatest(0, p_distance), now())
  on conflict (player_id) do update set display_name = excluded.display_name,
    best_distance = greatest(koopa_leaderboard.best_distance, excluded.best_distance), updated_at = now();
end;
$$;

create or replace function public.get_koopa_leaderboard(p_limit integer default 10)
returns table (display_name text, best_distance integer, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select display_name, best_distance, updated_at from koopa_leaderboard
  order by best_distance desc, updated_at asc limit least(greatest(p_limit, 1), 25);
$$;

revoke all on public.koopa_leaderboard from anon, authenticated;
grant execute on function public.submit_koopa_score(uuid, text, integer) to anon, authenticated;
grant execute on function public.get_koopa_leaderboard(integer) to anon, authenticated;
