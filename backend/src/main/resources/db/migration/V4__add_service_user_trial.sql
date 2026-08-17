ALTER TABLE service_user
    ADD COLUMN trial_started_at TIMESTAMP WITH TIME ZONE NULL;

ALTER TABLE service_user
    ADD COLUMN trial_expires_at TIMESTAMP WITH TIME ZONE NULL;

ALTER TABLE service_user
    ADD CONSTRAINT ck_service_user_trial_dates CHECK (
        (trial_started_at IS NULL AND trial_expires_at IS NULL)
        OR (trial_started_at IS NOT NULL AND trial_expires_at IS NOT NULL AND trial_expires_at > trial_started_at)
    );
