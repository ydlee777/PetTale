# StoreKit 2 development

Oreamy loads only `com.oreamy.app.premium.monthly` and
`com.oreamy.app.premium.annual`. The shared Xcode scheme uses
`OreamyTests/Oreamy.storekit` for local development. Its USD prices are test
fixtures; production UI always displays StoreKit's localized product price.

Local verified StoreKit entitlement is presentation state only in Step 8B. It
does not change the backend `FREE`/`PREMIUM_TRIAL` service plan and is never sent
as a client-controlled Premium assertion. Backend synchronization belongs to
Step 8C.

## Local testing

Run the Oreamy scheme, open Account → Oreamy Premium, then use Xcode's
StoreKit transaction manager to purchase, expire, revoke, or clear test
transactions. Test monthly and annual separately. Restore Purchases uses
`AppStore.sync()` and entitlement is re-derived from verified current
transactions.

## App Store Connect setup

Before sandbox or TestFlight validation:

1. Create the subscription group **Oreamy Premium**.
2. Create the monthly and annual products with the IDs above.
3. Add localized display names and descriptions.
4. Configure storefront pricing (US targets: $4.99 and $47.99).
5. Complete review metadata and availability.
6. Ensure agreements, tax, and banking are valid.
7. Wait until both products are available for sandbox/TestFlight testing.

No App Store introductory free trial is configured. Oreamy's 30-day trial is
backend-controlled and begins when the backend creates a new ServiceUser.
