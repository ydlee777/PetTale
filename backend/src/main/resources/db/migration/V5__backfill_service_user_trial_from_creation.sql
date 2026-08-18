UPDATE service_user
SET trial_started_at = created_at,
    trial_expires_at = created_at + INTERVAL '30' DAY
WHERE trial_started_at IS NULL
  AND trial_expires_at IS NULL;
