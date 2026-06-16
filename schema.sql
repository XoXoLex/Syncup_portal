-- ============================================================
--  SyncUp Bug & Feedback Portal — Supabase schema
--  Run this whole file in: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. PROFILES (roles) -----------------------------------------
-- One row per signed-in team member. role drives permissions.
create table if not exists profiles (
  id    uuid primary key references auth.users on delete cascade,
  name  text,
  role  text not null default 'reporter'
        check (role in ('reporter','tester','developer','admin'))
);

-- 2. REPORTS (bugs + feature requests) ------------------------
create table if not exists reports (
  id        text primary key,        -- e.g. BUG-1045 / FEAT-1046
  type      text not null default 'bug' check (type in ('bug','feature')),
  title     text not null,
  desc      text not null,
  module    text,
  severity  text default 'medium' check (severity in ('high','medium','low')),
  status    text default 'reported'
            check (status in ('reported','verified','assigned','in_progress','resolved','closed')),
  reporter  text,                     -- "guest:email@x.com" or a member name
  assignee  text default '—',
  due       text,                     -- due date (YYYY-MM-DD)
  created   text,
  shot      text                      -- screenshot URL (Supabase storage)
);

-- 3. ROW-LEVEL SECURITY ---------------------------------------
alter table reports enable row level security;

-- Anyone (even logged-out) can READ reports and FILE a new one.
-- This satisfies requirement #6: no sign-in needed to report.
create policy "anyone can read"   on reports for select using (true);
create policy "anyone can insert" on reports for insert with check (true);

-- Only signed-in testers / developers / admins can CHANGE a report.
-- This satisfies requirement #7: must be logged in (with a role) to act.
create policy "members can update" on reports for update
  using (
    exists (
      select 1 from profiles p
      where p.id = auth.uid()
        and p.role in ('tester','developer','admin')
    )
  );

-- Profiles: a user can see/edit only their own row.
alter table profiles enable row level security;
create policy "own profile read"  on profiles for select using (auth.uid() = id);
create policy "own profile write" on profiles for insert with check (auth.uid() = id);

-- 4. AUTO-CREATE a profile when someone signs up -------------
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'name','New user'), 'reporter');
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- NOTE: new members default to 'reporter'. To promote someone to tester /
-- developer / admin, edit their row in the profiles table (Table Editor),
-- or run:  update profiles set role='tester' where name='Aarya';

-- ============================================================
--  AUTH WIRING (frontend) — summary
--  In index.html, sign-in calls:
--    supabase.auth.signInWithPassword({ email, password })
--  and the current user's role is read from the profiles table.
--  The demo's name+role picker is replaced by this real flow.
-- ============================================================
