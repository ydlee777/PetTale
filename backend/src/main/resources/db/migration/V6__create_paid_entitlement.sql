CREATE TABLE paid_entitlement (
    id UUID PRIMARY KEY,
    service_user_id UUID NOT NULL REFERENCES service_user(id),
    product_id VARCHAR(128) NOT NULL,
    original_transaction_id VARCHAR(128) NOT NULL,
    latest_transaction_id VARCHAR(128) NOT NULL,
    app_account_token UUID NOT NULL,
    apple_environment VARCHAR(16) NOT NULL,
    verified_expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE NULL,
    revocation_reason VARCHAR(64) NULL,
    apple_signed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_verified_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uk_paid_entitlement_original_transaction UNIQUE (original_transaction_id),
    CONSTRAINT uk_paid_entitlement_latest_transaction UNIQUE (latest_transaction_id),
    CONSTRAINT ck_paid_entitlement_environment CHECK (apple_environment IN ('PRODUCTION', 'SANDBOX')),
    CONSTRAINT ck_paid_entitlement_product CHECK (product_id IN (
        'com.oreamy.app.premium.monthly',
        'com.oreamy.app.premium.annual'
    ))
);

CREATE INDEX ix_paid_entitlement_service_user ON paid_entitlement(service_user_id);
CREATE INDEX ix_paid_entitlement_active ON paid_entitlement(service_user_id, verified_expires_at, revoked_at);
