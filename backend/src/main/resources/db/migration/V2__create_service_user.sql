CREATE TABLE service_user (
    id UUID PRIMARY KEY,
    apple_subject VARCHAR(255) NOT NULL,
    email VARCHAR(320),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uk_service_user_apple_subject UNIQUE (apple_subject)
);
