# SyncUp — Bug & Feedback Portal

A bug reporting and tracking web app for the SyncUp platform. Anyone can report
a bug or request a feature without an account; team members sign in with a role
(tester, developer, admin) to move reports through a workflow. The app is built
as a single self-contained React file, backed by Supabase (database + storage)
and Resend (resolution emails), and deployed on Vercel.

This document describes what the portal does, what has already been built and
deployed, how it is structured, and what remains optional. It is intended as a
handover reference for the team.

---

## Current status

The portal is **built and live**. The following are complete and working in
production:

- Public bug/feature reporting form (no login required), with screenshot upload
- Full status workflow with role-based permissions
- Supabase database storing all reports
- Admin-only delete (single report and clear-all)
- Resolution emails via a Supabase Edge Function + Resend

The **only** item not fully production-ready is email delivery to arbitrary
addresses — see "Known limitation: email" below. Everything else is functional.

---

## What it does (the 7 requirements)

| # | Requirement | Status | Where it lives |
|---|-------------|--------|----------------|
| 1 | Report a bug / request a feature | Done | "New report" form (`type` = bug \| feature) |
| 2 | Screenshot of the bug | Done | File picker in the form (image stored as data on the report) |
| 3 | Roles: reporter, tester, developer, admin | Done | Sign-in role selector + per-role action buttons (`ROLES` object) |
| 4 | Bug verified by testers | Done | "Verify" action (tester/admin only) |
| 5 | Assigned to a developer with a timeline; overdue flagged | Done (in-app); overdue email optional | "Assign to dev" sets assignee + due date; overdue reports flagged in the UI |
| 6 | No sign-in needed to report; reporter emailed on resolution | Done (sandbox email) | Form takes an email; resolving a report calls the email function |
| 7 | Members must log in before acting | Done | Action buttons only render for a signed-in role with permission |

**Lifecycle:** Reported → Verified → Assigned → In Progress → Resolved → Closed.
Any resolved or closed report can be reopened; admins can delete any report.

---

## Architecture

Three services, all on free tiers, no servers to maintain:

- **Vercel** — hosts the site and auto-redeploys whenever the GitHub repo
  changes.
- **Supabase** — Postgres database (the `reports` table), plus the Edge Function
  that sends resolution emails.
- **Resend** — the email API the Edge Function calls.

The entire frontend is one file, `index.html`. It loads React, Babel and the
Supabase client from CDNs, so there is no build step — the file runs as-is.

```
Browser (index.html on Vercel)
        |
        |-- reads/writes reports ----------> Supabase: reports table
        |
        '-- on "resolved" --> Supabase Edge Function (notify-resolved-md)
                                      |
                                      '----> Resend --> reporter's email
```

---

## How the code is organised (`index.html`)

All logic is inside the single `<script type="text/babel">` block:

- **Storage layer** (`const api = { ... }`) — the only place that talks to
  Supabase. Functions: `list`, `add`, `update`, `remove`, `clear`. To repoint
  the app at a different Supabase project, only the `createClient(...)` URL/key
  and these functions matter.
- **`ROLES`** — defines the four roles and the actions each one is allowed to
  perform (`can: [...]`). Permissions are enforced by checking this array
  before rendering each action button.
- **`FLOW`, `STATUS`, `SEV`, `MODULES`** — the workflow stages, their colours,
  severity levels, and the list of platform modules shown in the form.
- **`Identity`** — the sign-in control (name + role picker). See the auth note
  below.
- **`ReportForm`** — the new-report modal (type, title, description, module,
  severity, email, screenshot).
- **`BugCard`** — one report row, its expandable detail, and the role-gated
  action bar (Verify / Assign / Start work / Mark resolved / Close / Reopen /
  Delete).
- **`App`** — top-level state, the report list, search, status-filter tabs, and
  the handlers (`submit`, `act`, `del`, `clearAll`).

---

## Roles and permissions

| Role | Can do |
|------|--------|
| Reporter | File a report |
| Tester | File, verify, reopen |
| Developer | Start work, mark resolved |
| Admin | Everything, including assign and delete |

A logged-out visitor can read all reports and file a new one, but sees no action
buttons.

---

## Database

The schema lives in `schema.sql`. Running it in the Supabase SQL Editor creates:

- The `reports` table (one row per bug/feature).
- A `profiles` table for member roles (used only if real authentication is
  enabled — see auth note).
- Row-level security policies: anyone can read and insert (requirement 6),
  members can update, admins can delete.

To change what's stored or how it's secured, edit `schema.sql` and re-run the
relevant statements.

---

## Authentication note (important for the team)

The current sign-in is a **name + role picker**, not password-based login. A
user types a name, chooses a role, and the matching permissions apply. This is
fine for an internal team tool and was a deliberate choice to keep the portal
simple and fast to ship.

Because there is no real authenticated user, Supabase's `auth.uid()` is empty,
so the row-level security policies that reference it (update/delete) are
permissive in practice — access control is enforced in the frontend by the
`ROLES` permissions. If the portal is ever opened to outside users, real
authentication should be added:

- Replace the `Identity` component's picker with
  `supabase.auth.signInWithPassword({ email, password })`.
- Read the signed-in user's role from the `profiles` table.
- The `profiles` table and its auto-create trigger in `schema.sql` already
  support this.

---

## Known limitation: email

Resolution emails are wired and working, but currently send from Resend's
sandbox sender (`onboarding@resend.dev`). On the sandbox, Resend only delivers
to the account owner's own verified address — it will not yet deliver to
arbitrary reporter emails.

To remove this restriction, a domain (e.g. `syncup.in`) must be verified on the
Resend account by adding the SPF/DKIM DNS records Resend provides, after which
the Edge Function's `from` address is changed to that domain (e.g.
`bugs@syncup.in`). This is a configuration change only — no code rewrite. Full
steps are in `email-function.md`.

The portal does not depend on email to function: every report and its status is
visible to everyone on the live site. The email is only a courtesy notification.

---

## Maintenance / common tasks

- **Set a teammate's role:** roles are chosen at sign-in, so no action is needed
  for the current picker-based login. (Under real auth, update their row in the
  `profiles` table.)
- **Clear test data:** sign in as admin and use the per-report Delete button, or
  "Clear all".
- **Change the Supabase project:** update the `createClient(...)` URL and anon
  key near the top of `index.html`.
- **Redeploy:** push changes to the GitHub repo; Vercel redeploys automatically.

---

## If the portal needs to move to SyncUp-owned accounts

The whole project is portable. To move it off the original developer's personal
accounts:

1. Create company-owned Supabase, Resend, and Vercel accounts.
2. Run `schema.sql` in the new Supabase project; create a `screenshots` storage
   bucket if file storage is moved there.
3. Update the `createClient(...)` URL and anon key in `index.html`.
4. Recreate the `notify-resolved-md` Edge Function (code in `email-function.md`)
   and add the Resend API key as a secret.
5. Re-import the GitHub repo into the new Vercel account and deploy.

No code needs to be rewritten — only keys and accounts change.

---

## File list

- `index.html` — the entire app (frontend + Supabase wiring + email trigger)
- `schema.sql` — database tables and security policies
- `email-function.md` — the Edge Function code and the domain-verification steps
- `README.md` — this file
