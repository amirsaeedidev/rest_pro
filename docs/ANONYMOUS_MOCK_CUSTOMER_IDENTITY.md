# Guest identity for the mock customer login

The customer-facing phone/OTP screens remain mock. No SMS is sent and no real OTP is verified.

## Supabase setting

In the Supabase Dashboard for this project:

1. Open **Authentication → Sign In / Providers**.
2. Enable **Allow anonymous sign-ins**.
3. Save the setting.

Anonymous sign-in is required because the app now creates an isolated Supabase Auth user instead of signing every customer into the shared `dev@restaurant.test` account.

## Runtime behavior

- The mock UI still accepts the configured mock code. The default is `1234`.
- To change the UI-only code for a local debug run, pass `--dart-define=MOCK_LOGIN_CODE=...`.
- After the mock code is accepted, Flutter calls `signInAnonymously()` only when this installation has no Supabase session.
- The generated Auth UID owns that installation's customer profile, orders, wallet, loyalty wallet and targeted discounts through the existing RLS policies.
- UI sign-out clears the mock login state but deliberately retains the anonymous Supabase session so the same installation does not lose access to its existing customer data.
- Clearing app data, uninstalling the app or using another device creates a different anonymous identity. Anonymous identities cannot be recovered on another device without a future account-linking/authentication flow.
- The phone typed into the mock screen is not verified and is not treated as a verified server-side identity.

## Security boundaries

- Anonymous users receive the Postgres `authenticated` role, but row access remains restricted by `auth.uid()` ownership and admin checks.
- Do not add policies that grant anonymous users broad access merely because they are `authenticated`.
- Do not ship a service-role key or admin credential in Flutter.
- Keep wallet, loyalty, order totals, payment mode and inventory mutations behind guarded database functions/triggers.
