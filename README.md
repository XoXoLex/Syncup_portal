# SyncUp — Bug & Feedback Portal

A bug reporting and tracking portal. Anyone can report a bug or request a
feature (no account needed); testers, developers and admins sign in to move
reports through a workflow.

This folder contains a **working demo** (`index.html`) that runs in any browser
with no setup — open it and click around. Data is held in memory, so it resets
on refresh. The steps below turn it into a **real, deployed app** with login,
a database, file uploads, and resolution emails.

---

## What it does (the 7 requirements)

| # | Requirement | Where it lives |
|---|-------------|----------------|
| 1 | Report a bug / request a feature | "New report" form (`type` = bug \| feature) |
| 2 | Screenshot of the bug | File picker in the form (image upload) |
| 3 | Roles: reporter, tester, developer, admin | Sign-in role selector + per-role action buttons |
| 4 | Bug verified by testers | "Verify" action (tester/admin only) |
| 5 | Assigned to developer with a timeline; overdue → notify admin + tester | "Assign to dev" sets assignee + due date; overdue rows flag and (when deployed) trigger an email |
| 6 | No sign-in to report; email gets the update | Form takes an email; "resolved" queues the thank-you notification |
| 7 | Tester must log in before assigning | Action buttons only appear when signed in with the right role |

**Lifecycle:** Reported → Verified → Assigned → In Progress → Resolved → Closed
(any resolved/closed item can be Reopened).

---

## Try the demo right now

Double-click `index.html`. It opens in your browser. Click **Sign in to act**,
pick a role, and the matching action buttons appear on each report. No internet
or install needed.

> The demo's login is just a name + role picker, and data resets on refresh.
> That's intentional — it's for showing the flows. Real login and saved data
> come from the steps below.

---

## Turning it into a real app (the deploy plan)

Three free services, no servers to manage:

1. **GitHub** — stores the code so the team can share it.
2. **Supabase** — the database, real login, and screenshot storage.
3. **Vercel** — hosts the website at a real URL.

### Step 1 — Put the code on GitHub
1. Make a free account at github.com.
2. Create a new repository called `syncup-bug-portal`.
3. Upload the contents of this folder (the upload button works fine — no
   command line needed).

### Step 2 — Set up Supabase (database + auth + storage)
1. Make a free account at supabase.com and create a project.
2. Open the **SQL Editor** and run the script in `schema.sql` (in this folder).
   It creates the `reports` table, the `profiles` (roles) table, and the
   security rules that enforce requirement #7 (only signed-in testers/admins
   can change things).
3. Create a storage bucket named `screenshots` (public read).
4. From **Project Settings → API**, copy the **Project URL** and the
   **anon public key**.

### Step 3 — Connect the app to Supabase
In `index.html`, find the block marked `STORAGE LAYER`. Replace the four
`api.*` functions with the Supabase versions below, and add the Supabase
script tag in `<head>`:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

```js
const supabase = window.supabase.createClient(
  "PASTE_PROJECT_URL_HERE",
  "PASTE_ANON_KEY_HERE"
);
const api = {
  list:   async () => (await supabase.from("reports").select("*").order("created",{ascending:false})).data || [],
  add:    async (b) => { await supabase.from("reports").insert(b); },
  update: async (id, patch) => { await supabase.from("reports").update(patch).eq("id", id); },
};
```

That's the only code change. Login wiring (Supabase Auth) and the email
function are described in `schema.sql` comments and `email-function.md`.

### Step 4 — Deploy on Vercel
1. Make a free account at vercel.com.
2. "Import" your GitHub repo.
3. Click Deploy. You get a live URL like `syncup-bug-portal.vercel.app`.

Every time you push a change to GitHub, Vercel re-deploys automatically.

---

## What still needs a developer

- **Real email sending** (requirements 5 & 6): needs a Supabase Edge Function
  plus a free Resend account — see `email-function.md`. The app already
  *queues* the message and shows it; this just makes it actually send.
- **Overdue auto-check** (requirement 5): a scheduled Supabase function that
  runs daily and emails admin + tester for any past-due, unresolved bug.

Both are small and well-documented; flag me when you're ready and I'll write them.

---

## File list
- `index.html` — the whole app (demo-ready; one block to swap for production)
- `schema.sql` — database tables + security rules for Supabase
- `email-function.md` — how to wire real resolution/overdue emails
- `README.md` — this file
