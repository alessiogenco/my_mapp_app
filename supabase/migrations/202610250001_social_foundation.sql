-- My Locals social foundation
-- Run this migration in a new Supabase project before connecting the app.
-- It is deliberately independent from assets/data/places.json: place_id uses
-- the existing stable JSON id until curated places move to the database.

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text unique,
  display_name text,
  avatar_url text,
  share_ratings_with_friends boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_handle_format check (
    handle is null or handle ~ '^[a-z0-9_]{3,24}$'
  )
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;

create policy "authenticated members can view profiles"
on public.profiles for select to authenticated
using (true);

create policy "members create only their own profile"
on public.profiles for insert to authenticated
with check (auth.uid() = id);

create policy "members update only their own profile"
on public.profiles for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint friendships_distinct_members check (requester_id <> addressee_id)
);

create unique index friendships_unique_pair
on public.friendships (
  least(requester_id, addressee_id),
  greatest(requester_id, addressee_id)
);

alter table public.friendships enable row level security;
revoke all on public.friendships from anon, authenticated;
grant select, insert, update, delete on public.friendships to authenticated;

create policy "members can view their friendships"
on public.friendships for select to authenticated
using (auth.uid() in (requester_id, addressee_id));

create policy "members can send friendship requests"
on public.friendships for insert to authenticated
with check (auth.uid() = requester_id and status = 'pending');

create policy "recipients can respond to pending requests"
on public.friendships for update to authenticated
using (auth.uid() = addressee_id and status = 'pending')
with check (
  auth.uid() = addressee_id
  and status in ('accepted', 'declined', 'blocked')
);

create policy "requesters can cancel pending requests"
on public.friendships for delete to authenticated
using (auth.uid() = requester_id and status = 'pending');

create or replace function public.are_accepted_friends(
  first_member_id uuid,
  second_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select first_member_id <> second_member_id and exists (
    select 1
    from public.friendships
    where status = 'accepted'
      and (
        (requester_id = first_member_id and addressee_id = second_member_id)
        or (requester_id = second_member_id and addressee_id = first_member_id)
      )
  );
$$;

create or replace function public.can_view_member_ratings(
  viewer_id uuid,
  owner_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select viewer_id = owner_id or exists (
    select 1
    from public.profiles
    where id = owner_id
      and share_ratings_with_friends
      and public.are_accepted_friends(viewer_id, owner_id)
  );
$$;

revoke all on function public.are_accepted_friends(uuid, uuid) from public;
revoke all on function public.can_view_member_ratings(uuid, uuid) from public;
grant execute on function public.are_accepted_friends(uuid, uuid) to authenticated;
grant execute on function public.can_view_member_ratings(uuid, uuid) to authenticated;

create table public.place_ratings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  place_id text not null check (char_length(place_id) between 1 and 160),
  rating smallint not null check (rating between 1 and 10),
  rating_details jsonb not null default '{}'::jsonb,
  note text check (char_length(note) <= 1000),
  is_recommended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint place_ratings_one_rating_per_place unique (user_id, place_id)
);

create trigger place_ratings_set_updated_at
before update on public.place_ratings
for each row execute procedure public.set_updated_at();

alter table public.place_ratings enable row level security;
revoke all on public.place_ratings from anon, authenticated;
grant select, insert, update, delete on public.place_ratings to authenticated;

create policy "members can read ratings shared with them"
on public.place_ratings for select to authenticated
using (public.can_view_member_ratings(auth.uid(), user_id));

create policy "members create only their own ratings"
on public.place_ratings for insert to authenticated
with check (auth.uid() = user_id);

create policy "members update only their own ratings"
on public.place_ratings for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "members delete only their own ratings"
on public.place_ratings for delete to authenticated
using (auth.uid() = user_id);

create table public.place_submissions (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 160),
  city text not null check (char_length(trim(city)) between 1 and 120),
  google_maps_url text,
  note text check (char_length(note) <= 1000),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewer_id uuid references public.profiles (id) on delete set null
);

alter table public.place_submissions enable row level security;
revoke all on public.place_submissions from anon, authenticated;
grant select, insert, delete on public.place_submissions to authenticated;

create policy "members can view their own submissions"
on public.place_submissions for select to authenticated
using (auth.uid() = author_id);

create policy "members can send pending submissions"
on public.place_submissions for insert to authenticated
with check (auth.uid() = author_id and status = 'pending');

create policy "members can withdraw pending submissions"
on public.place_submissions for delete to authenticated
using (auth.uid() = author_id and status = 'pending');
