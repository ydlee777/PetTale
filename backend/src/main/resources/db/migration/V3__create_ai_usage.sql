CREATE TABLE ai_usage (
    id UUID PRIMARY KEY,
    service_user_id UUID NOT NULL REFERENCES service_user(id),
    operation VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    provider VARCHAR(64),
    model VARCHAR(255),
    input_tokens BIGINT,
    output_tokens BIGINT,
    provider_request_id VARCHAR(255),
    failure_category VARCHAR(64),
    CONSTRAINT ck_ai_usage_tokens_nonnegative CHECK (
        (input_tokens IS NULL OR input_tokens >= 0)
        AND (output_tokens IS NULL OR output_tokens >= 0)
    )
);

CREATE INDEX ix_ai_usage_monthly_quota
    ON ai_usage (service_user_id, operation, requested_at, status);
