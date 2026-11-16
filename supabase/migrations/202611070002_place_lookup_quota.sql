-- My Locals Google Places lookup guardrail.
-- The Google key stays in a Supabase Edge Function. This table records only
-- request timestamps, so we can give every signed-in member a small daily
-- lookup allowance without storing Google Place content.

begin;

create table public.place_lookup_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index place_lookup_events_user_created_at_index
  on public.place_lookup_events (user_id, created_at desc);

alter table public.place_lookup_events enable row level security;
revoke all on public.place_lookup_events from anon, authenticated;

-- The Edge Function calls this with the service role. The advisory lock makes
-- the count-and-insert operation safe when a member clicks twice quickly.
create or replace function public.consume_place_lookup_quota(
  p_user_id uuid,
  p_limit integer default 100
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Keep this cap aligned with place-search: each signed-in member may use
  -- up to 100 Google Places lookups per UTC day.
  lookup_limit integer := least(greatest(coalesce(p_limit, 100), 1), 100);
  lookups_today integer;
  utc_day_start timestamptz := date_trunc(
    'day',
    now() at time zone 'UTC'
  ) at time zone 'UTC';
begin
  perform pg_advisory_xact_lock(hashtext(p_user_id::text));

  select count(*)
    into lookups_today
  from public.place_lookup_events
  where user_id = p_user_id
    and created_at >= utc_day_start;

  if lookups_today >= lookup_limit then
    return false;
  end if;

  insert into public.place_lookup_events (user_id)
  values (p_user_id);

  return true;
end;
$$;

revoke all on function public.consume_place_lookup_quota(uuid, integer)
  from public;
grant execute on function public.consume_place_lookup_quota(uuid, integer)
  to service_role;

commit;
