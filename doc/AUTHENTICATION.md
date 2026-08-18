# Authentication foundation

Oreamy keeps pet profiles and history in the iOS SwiftData/CloudKit boundary. Signing in is optional for local use and establishes only the service identity needed by future backend-dependent features.

## Flow

1. The iOS app creates a cryptographically random nonce and sends its SHA-256 hash with the native `AuthenticationServices` authorization request.
2. The app sends Apple's identity token and the original nonce to `POST /api/v1/auth/apple`.
3. The backend verifies the token signature with Apple's JWK set and validates expiration, issuer, audience, subject, and nonce. Only a verified email claim may be captured; Apple subject is the external identity key.
4. The backend resolves or creates one `service_user` and returns a Oreamy HS256 JWT whose subject is the internal user UUID. The V1 default lifetime is 30 days and remains configurable.
5. iOS stores only the Oreamy session in a device-only Keychain item. Sign out removes it; Apple tokens and nonces are not persisted.

The health endpoint and Apple authentication entry point are public. Every other backend endpoint requires a valid Oreamy bearer token. Tokens, nonces, and signing material must not be logged.

`GET /api/v1/service-access` derives ownership exclusively from the verified Oreamy JWT subject. It does not accept a user ID, Apple subject, or email from the client and returns only service plan, trial dates/eligibility, and monthly AI allowance usage.

## Configuration

Backend configuration is supplied through `OREAMY_APPLE_AUDIENCE`, `OREAMY_APPLE_ISSUER`, `OREAMY_APPLE_JWK_SET_URI`, `OREAMY_SESSION_ISSUER`, `OREAMY_SESSION_LIFETIME`, and `OREAMY_SESSION_SIGNING_KEY`. The signing key is Base64-encoded material of at least 32 random bytes and must remain outside source control.

The iOS Debug build uses `OREAMY_API_BASE_URL=http://127.0.0.1:8080` for Simulator development. Set the Release build value to the real HTTPS service URL before distribution.

## Apple Developer setup

Enable Sign in with Apple for App ID `com.oreamy.app`, refresh the development/distribution provisioning profiles, and confirm that the selected team can sign the checked-in entitlement. The backend audience must exactly match the identifier represented by Apple's `aud` claim. Real authorization and returning-user behavior must be verified on a provisioned physical device; automated tests use controlled keys and do not contact Apple.
