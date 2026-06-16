# Email notifications (requirements 5 & 6)

The app already *queues* and displays the right messages. To make them actually
send, you need a tiny serverless function and a free email service. ~20 minutes.

## What you'll set up
- **Resend** (resend.com) — free email API, 100 emails/day free.
- **Supabase Edge Function** — runs the send when a bug is resolved or overdue.

## A) Resolution email (requirement 6)
When a report's status becomes `resolved`, email the reporter:
> "Your report has been resolved — thank you for letting us know."

1. Make a free Resend account, verify a sender address, copy the API key.
2. In Supabase → Edge Functions, create a function `notify-resolved`:

```ts
import { serve } from "https://deno.land/std/http/server.ts";
serve(async (req) => {
  const { email, reportId, title } = await req.json();
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "SyncUp <bugs@yourdomain.com>",
      to: email,
      subject: `Your report ${reportId} has been resolved`,
      text: `Your report "${title}" has been resolved — thank you for letting us know.`,
    }),
  });
  return new Response("ok");
});
```

3. Add `RESEND_API_KEY` as a secret in the function settings.
4. In `index.html`, where the app shows the "Notification queued" message,
   also call the function:

```js
await fetch("https://YOUR_PROJECT.functions.supabase.co/notify-resolved", {
  method: "POST",
  body: JSON.stringify({ email: reporterEmail, reportId: b.id, title: b.title }),
});
```

## B) Overdue alert (requirement 5)
Email admin + assigned tester when a report passes its `due` date without being
resolved.

1. Create a function `check-overdue` that queries reports where
   `due < today` and `status` is not `resolved`/`closed`, and emails each
   one's admin + tester (same Resend pattern as above).
2. In Supabase → Database → Cron, schedule it daily:

```sql
select cron.schedule('overdue-check', '0 9 * * *',
  $$ select net.http_post(
       url := 'https://YOUR_PROJECT.functions.supabase.co/check-overdue'
     ); $$);
```

That's it — once these two are live, every box on the requirements list is
fully functional. Ping me and I'll tailor the exact code to your Supabase
project once it exists.
