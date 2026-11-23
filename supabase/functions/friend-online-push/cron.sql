-- Run once in Supabase SQL editor after deploying friend-online-push.
-- Requires pg_cron + pg_net enabled.
-- Replace project ref and service role key before running.
select cron.schedule(
  'friend-online-push-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/friend-online-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>'
    ),
    body := '{}'::jsonb
  );
  $$
);
