-- ============================================================
--  SyncUp Bug & Feedback Portal — Supabase schema
--  Run this whole file in: Supabase Dashboard -> SQL Editor
-- ============================================================

-- 1. REPORTS (bugs + feature requests) ------------------------
create table if not exists reports (
  id        text primary key,        -- e.g. BUG-1045 / FEAT-1046
  type      text not null default 'bug' check (type in ('bug','feature')),
  title     text not null,
  "desc"    text not null,           -- note: 'desc' is a SQL keyword; the
                                     -- deployed table uses this column name,
                                     -- and Supabase's client quotes it
                                     -- automatically, so it works as-is.
  module    text,
  severity  text default 'medium' check (severity in ('high','medium','low')),
  status    text default 'reported'
            check (status in ('reported','verified','assigned','in_progress','resolved','closed')),
  reporter  text,                     -- "guest:email@x.com" or a member name
  assignee  text default '—',
  due       text,                     -- due date (YYYY-MM-DD)
  created   text,
  shot      text                      -- screenshot (data URL)
);

-- 2. PROFILES (roles) -----------------------------------------
-- Only used if real password authentication is enabled later.
-- The current app uses a name + role picker, so this table is
-- optional until then (see the AUTH NOTE at the bottom).
create table if not exists profiles (
  id    uuid primary key references auth.users on delete cascade,
  name  text,
  role  text not null default 'reporter'
        check (role in ('reporter','tester','developer','admin'))
);

-- 3. ROW-LEVEL SECURITY ---------------------------------------
alter table reports enable row level security;

-- Anyone (even logged-out) can READ reports and FILE a new one.
-- Satisfies requirement #6: no sign-in needed to report.
create policy "anyone can read"   on reports for select using (true);
create policy "anyone can insert" on reports for insert with check (true);

-- IMPORTANT — see AUTH NOTE below.
-- The app currently uses a name+role picker, NOT real Supabase Auth, so
-- auth.uid() is always empty. Policies that check auth.uid() would block
-- ALL updates/deletes. The two policies below are therefore written to be
-- permissive, and access control is enforced in the frontend (the ROLES
-- object only shows action buttons to the right role).
create policy "allow update" on reports for update using (true);
create policy "allow delete" on reports for delete using (true);

-- ------------------------------------------------------------
-- WHEN REAL AUTH IS ADDED, drop the two permissive policies above
-- and use these stricter ones instead:
--
--   drop policy "allow update" on reports;
--   drop policy "allow delete" on reports;
--
--   create policy "members can update" on reports for update using (
--     exists (select 1 from profiles p
--             where p.id = auth.uid()
--               and p.role in ('tester','developer','admin')));
--
--   create policy "admins can delete" on reports for delete using (
--     exists (select 1 from profiles p
--             where p.id = auth.uid()
--               and p.role = 'admin'));
-- ------------------------------------------------------------

-- Profiles RLS (for the real-auth path)
alter table profiles enable row level security;
create policy "own profile read"  on profiles for select using (auth.uid() = id);
create policy "own profile write" on profiles for insert with check (auth.uid() = id);

-- 4. AUTO-CREATE a profile on signup (real-auth path only) ----
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

-- To promote someone once real auth is on:
--   update profiles set role='tester' where name='Aarya';

-- ============================================================
--  AUTH NOTE
--  The deployed app signs in with a name + role picker (no password).
--  This is intentional for an internal team tool. Permissions are
--  enforced in index.html via the ROLES object. If the portal is opened
--  to outside users, switch the Identity component to
--  supabase.auth.signInWithPassword(...) and use the stricter policies
--  shown above. The profiles table + trigger are already here for that.
-- ============================================================
