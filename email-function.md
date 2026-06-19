# Email notifications

This document describes the resolution-email feature: what is already built and
working, and the one configuration step needed to send to any reporter (not just
the account owner).

---

## What is already built and live

When a report's status is set to **resolved**, the app calls a Supabase Edge
Function named `notify-resolved-md`, which uses Resend to email the reporter:

> "Your report **<title>** has been resolved — thank you for letting us know."

This is wired end-to-end and works today. The frontend trigger is in
`index.html`, inside the `act` handler:

```js
if (patch.status === "resolved") {
  const targetBug = bugs.find(b => b.id === id);
  const reporterEmail = targetBug.reporter.replace("guest:", "");
  await fetch("https://anuupbdmcqralxskdyur.supabase.co/functions/v1/notify-resolved-md", {
    method: "POST",
    body: JSON.stringify({ email: reporterEmail, reportId: targetBug.id, title: targetBug.title }),
  });
}
```

The deployed Edge Function (`notify-resolved-md`) looks like this:

```ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Resend } from "npm:resend@2.0.0"

const resend = new Resend(Deno.env.get("RESEND_API_KEY"))

serve(async (req) => {
  let body;
  try {
    body = await req.json();
  } catch (e) {
    return new Response("Invalid JSON body", { status: 400 });
  }

  const { email, reportId, title } = body;
  if (!email) return new Response("Missing email", { status: 400 });

  const { data, error } = await resend.emails.send({
    from: 'onboarding@resend.dev',
    to: [email],
    subject: `Bug ${reportId} Resolved`,
    html: `<p>Your report <strong>${title}</strong> has been resolved — thank you for letting us know.</p>`
  });

  if (error) return new Response(JSON.stringify(error), { status: 400 });
  return new Response(JSON.stringify(data), { status: 200 });
})
```

The Resend API key is stored as a secret named `RESEND_API_KEY` in the Edge
Function settings (Supabase → Edge Functions → notify-resolved-md → Secrets).

---

## The one remaining step: send to any address

The function currently sends from Resend's sandbox sender,
`onboarding@resend.dev`. On the sandbox, Resend only delivers to the Resend
account owner's own verified email. To send to any reporter's address, a domain
must be verified on Resend.

### Verify a domain (one-time)

1. In the Resend dashboard, go to **Domains → Add Domain** and enter the domain
   (e.g. `syncup.in`).
2. Resend shows a set of DNS records (an MX record, an SPF TXT record, and DKIM
   TXT records).
3. Add those records in the domain's DNS settings (wherever the domain is
   managed — e.g. the registrar or Cloudflare). Copy each record's name and
   value exactly.
4. Back in Resend, click **Verify**. Propagation can take anywhere from a few
   minutes to 24 hours.
5. Once the domain shows **Verified**, change the function's `from` line to an
   address on that domain:

```ts
from: 'bugs@syncup.in',
```

Redeploy the function. Emails will then deliver to any reporter.

> Optional cleanup: the subject line currently reads `Bug <id> Resolved` even for
> feature requests (giving e.g. "Bug FEAT-1052 Resolved"). To make it accurate:
> `subject: \`${reportId.startsWith('FEAT') ? 'Feature request' : 'Bug'} ${reportId} resolved\`,`

---

## Optional: overdue alerts

Not currently built. The app flags overdue reports in the UI, but does not email
anyone. To add automatic overdue emails:

1. Create a second Edge Function `check-overdue` that queries `reports` where
   `due < today` and `status` is not `resolved`/`closed`, and emails the admin
   and the assigned developer (same Resend pattern as above).
2. Schedule it to run daily via Supabase → Database → Cron:

```sql
select cron.schedule('overdue-check', '0 9 * * *',
  $$ select net.http_post(
       url := 'https://YOUR_PROJECT.functions.supabase.co/check-overdue'
     ); $$);
```
