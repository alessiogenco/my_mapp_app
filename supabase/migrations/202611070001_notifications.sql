-- My Locals notification centre
-- Important activity is the default. Place-submission notifications are
-- aggregated once per friend per day to avoid a noisy activity feed.

begin;

alter table public.profiles
  add column if not exists notification_preference text not null default 'important';

alter table public.profiles
  drop constraint if exists profiles_notification_preference_check;

alter table public.profiles
  add constraint profiles_notification_preference_check
  check (notification_preference in ('important', 'all', 'off'));

create table public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  type text not null check (
    type in (
      'friend_request',
      'friend_request_accepted',
      'friend_place_added'
    )
  ),
  importance smallint not null default 2 check (importance between 1 and 2),
  title text not null check (char_length(title) between 1 and 160),
  body text,
  metadata jsonb not null default '{}'::jsonb,
  aggregation_key text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index app_notifications_recipient_created_at_idx
  on public.app_notifications (recipient_id, created_at desc);

create index app_notifications_recipient_unread_idx
  on public.app_notifications (recipient_id)
  where read_at is null;

create unique index app_notifications_recipient_aggregation_key_idx
  on public.app_notifications (recipient_id, aggregation_key)
  where aggregation_key is not null;

alter table public.app_notifications enable row level security;
revoke all on public.app_notifications from anon, authenticated;
grant select, update on public.app_notifications to authenticated;

create policy "members read only their notifications"
on public.app_notifications for select to authenticated
using (auth.uid() = recipient_id);

create policy "members mark only their notifications as read"
on public.app_notifications for update to authenticated
using (auth.uid() = recipient_id)
with check (auth.uid() = recipient_id);

create or replace function public.notification_preference_allows(
  member_id uuid,
  incoming_importance smallint
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select case notification_preference
        when 'off' then false
        when 'all' then true
        else incoming_importance >= 2
      end
      from public.profiles
      where id = member_id
    ),
    false
  );
$$;

create or replace function public.notification_actor_label(member_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(display_name, ''),
    case when nullif(handle, '') is not null then '@' || handle end,
    'A friend'
  )
  from public.profiles
  where id = member_id;
$$;

create or replace function public.notify_on_friend_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_label text;
begin
  if not public.notification_preference_allows(new.addressee_id, 2) then
    return new;
  end if;

  actor_label := coalesce(
    public.notification_actor_label(new.requester_id),
    'A friend'
  );

  insert into public.app_notifications (
    recipient_id,
    actor_id,
    type,
    importance,
    title,
    body,
    metadata
  ) values (
    new.addressee_id,
    new.requester_id,
    'friend_request',
    2,
    'New friend request',
    actor_label || ' wants to connect with you.',
    jsonb_build_object('friendship_id', new.id)
  );

  return new;
end;
$$;

create or replace function public.notify_on_friendship_accepted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_label text;
begin
  if old.status <> 'pending' or new.status <> 'accepted' then
    return new;
  end if;

  if not public.notification_preference_allows(new.requester_id, 2) then
    return new;
  end if;

  actor_label := coalesce(
    public.notification_actor_label(new.addressee_id),
    'A friend'
  );

  insert into public.app_notifications (
    recipient_id,
    actor_id,
    type,
    importance,
    title,
    body,
    metadata
  ) values (
    new.requester_id,
    new.addressee_id,
    'friend_request_accepted',
    2,
    'Friend request accepted',
    actor_label || ' is now your friend.',
    jsonb_build_object('friendship_id', new.id)
  );

  return new;
end;
$$;

create or replace function public.notify_on_place_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  friend_id uuid;
  actor_label text;
  daily_key text;
begin
  actor_label := coalesce(
    public.notification_actor_label(new.author_id),
    'A friend'
  );

  for friend_id in
    select case
      when requester_id = new.author_id then addressee_id
      else requester_id
    end
    from public.friendships
    where status = 'accepted'
      and new.author_id in (requester_id, addressee_id)
  loop
    if not public.notification_preference_allows(friend_id, 2) then
      continue;
    end if;

    daily_key := format(
      'friend_place_added:%s:%s:%s',
      new.author_id,
      friend_id,
      current_date
    );

    insert into public.app_notifications (
      recipient_id,
      actor_id,
      type,
      importance,
      title,
      body,
      metadata,
      aggregation_key
    ) values (
      friend_id,
      new.author_id,
      'friend_place_added',
      2,
      actor_label || ' added a place',
      new.name || ' · ' || new.city,
      jsonb_build_object(
        'count', 1,
        'latest_place_name', new.name,
        'latest_place_city', new.city
      ),
      daily_key
    )
    on conflict (recipient_id, aggregation_key)
    where aggregation_key is not null
    do update set
      title = actor_label || ' added ' ||
        (
          coalesce(
            (public.app_notifications.metadata ->> 'count')::integer,
            1
          ) + 1
        ) || ' places today',
      body = excluded.body,
      metadata = public.app_notifications.metadata || jsonb_build_object(
        'count',
        coalesce(
          (public.app_notifications.metadata ->> 'count')::integer,
          1
        ) + 1,
        'latest_place_name', new.name,
        'latest_place_city', new.city
      ),
      read_at = null,
      created_at = now();
  end loop;

  return new;
end;
$$;

drop trigger if exists friendships_notify_friend_request on public.friendships;
create trigger friendships_notify_friend_request
after insert on public.friendships
for each row execute procedure public.notify_on_friend_request();

drop trigger if exists friendships_notify_friendship_accepted on public.friendships;
create trigger friendships_notify_friendship_accepted
after update on public.friendships
for each row execute procedure public.notify_on_friendship_accepted();

drop trigger if exists place_submissions_notify_friends on public.place_submissions;
create trigger place_submissions_notify_friends
after insert on public.place_submissions
for each row execute procedure public.notify_on_place_submission();

revoke all on function public.notification_preference_allows(uuid, smallint)
  from public;
revoke all on function public.notification_actor_label(uuid)
  from public;
revoke all on function public.notify_on_friend_request()
  from public;
revoke all on function public.notify_on_friendship_accepted()
  from public;
revoke all on function public.notify_on_place_submission()
  from public;

commit;
