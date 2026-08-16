# Authentication foundation

Pettale keeps pet profiles and history in the iOS SwiftData/CloudKit boundary. Signing in is optional for local use and establishes only the service identity needed by future backend-dependent features.

## Flow

1. The iOS app creates a cryptographically random nonce and sends its SHA-256 hash with the native `AuthenticationServices` authorization request.
2. The app sends Apple's identity token and the original nonce to `POST /api/v1/auth/apple`.
3. The backend verifies the token signature with Apple's JWK set and validates expiration, issuer, audience, subject, and nonce. Only a verified email claim may be captured; Apple subject is the external identity key.
4. The backend resolves or creates one `service_user` and returns a Pettale HS256 JWT whose subject is the internal user UUID. The V1 default lifetime is 30 days and remains configurable.
5. iOS stores only the Pettale session in a device-only Keychain item. Sign out removes it; Apple tokens and nonces are not persisted.

The health endpoint and Apple authentication entry point are public. Every other backend endpoint requires a valid Pettale bearer token. Tokens, nonces, and signing material must not be logged.

## Configuration

Backend configuration is supplied through `PETTALE_APPLE_AUDIENCE`, `PETTALE_APPLE_ISSUER`, `PETTALE_APPLE_JWK_SET_URI`, `PETTALE_SESSION_ISSUER`, `PETTALE_SESSION_LIFETIME`, and `PETTALE_SESSION_SIGNING_KEY`. The signing key is Base64-encoded material of at least 32 random bytes and must remain outside source control.

The iOS Debug build uses `PETTALE_API_BASE_URL=http://127.0.0.1:8080` for Simulator development. Set the Release build value to the real HTTPS service URL before distribution.

## Apple Developer setup

Enable Sign in with Apple for App ID `com.pettale.app`, refresh the development/distribution provisioning profiles, and confirm that the selected team can sign the checked-in entitlement. The backend audience must exactly match the identifier represented by Apple's `aud` claim. Real authorization and returning-user behavior must be verified on a provisioned physical device; automated tests use controlled keys and do not contact Apple.
