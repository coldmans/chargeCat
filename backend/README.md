# Charge Cat Backend

Charge Cat Pro now uses a small backend so the macOS app can open checkout in the browser, unlock Pro automatically on the same Mac, and support more than one payment provider.

## What It Does

- Creates app-linked checkout sessions for `toss` or `lemon`
- Hosts a Toss Payments widget page for domestic checkout
- Verifies Lemon webhooks with `X-Signature`
- Stores checkout sessions, issued licenses, license activations, and webhook logs in SQLite
- Exposes polling APIs so the macOS app can detect paid sessions
- Re-opens Charge Cat after checkout finishes
- Exposes backend-issued `ccp_...` license activation / validation / deactivation endpoints
- Keeps Lemon checkout available for global purchases
- Exposes a backend-managed downloadable animation catalog for Pro asset packs

## Checkout Providers

- `toss`
  - Default provider when `DEFAULT_CHECKOUT_PROVIDER=toss`
  - Used for browser checkout via Toss widget
  - On successful payment, the backend issues a `ccp_...` Charge Cat license key
- `lemon`
  - Keeps the existing Lemon Squeezy flow for global checkout and My Orders
  - Lemon licenses still validate against Lemon's License API in the app

## Routes

- `GET /healthz`
- `POST /api/checkout-sessions`
- `GET /api/checkout-sessions/:sessionId`
- `POST /api/checkout-sessions/:sessionId/claim`
- `POST /api/licenses/activate`
- `POST /api/licenses/validate`
- `POST /api/licenses/deactivate`
- `GET /api/assets/catalog`
- `GET /api/assets/download/:assetId`
- `POST /webhooks/lemon`
- `GET /buy/pro`
- `GET /checkout/toss/:sessionId`
- `GET /checkout/toss/success`
- `GET /checkout/toss/fail`
- `GET /checkout/return`
- `GET /checkout/thanks`

## Local Setup

1. Copy `.env.example` to `.env`
2. Fill in your public base URL and at least one provider:
   - Toss: `TOSS_WIDGET_CLIENT_KEY`, `TOSS_SECRET_KEY`
   - Lemon: `LEMON_API_KEY`, `LEMON_WEBHOOK_SECRET`, `LEMON_STORE_ID`, `LEMON_PRODUCT_ID`, `LEMON_VARIANT_ID`
3. Optional: add downloadable Pro animation files under `backend/assets/files/` and list them in `backend/assets/catalog.json`
3. Install dependencies
4. Run the server

```bash
cd backend
npm install
npm run dev
```

`npm run dev` and `npm start` automatically load `.env` when it exists.

## Toss Setup

- Set `PUBLIC_BASE_URL` to the HTTPS URL where this backend is reachable.
- Use your Toss widget client key in `TOSS_WIDGET_CLIENT_KEY`.
- Use your Toss secret key in `TOSS_SECRET_KEY`.
- If you have a custom widget layout, set `TOSS_WIDGET_VARIANT_KEY`. Otherwise keep `DEFAULT`.
- `PRO_PRICE_KRW` should match the amount you request and confirm for Charge Cat Pro.

This backend confirms payments server-side with Toss's `POST /v1/payments/confirm` API and then creates Charge Cat's own `ccp_...` license key. Toss integration details come from the official widget and core API docs:

- [Toss widget integration](https://docs.tosspayments.com/en/integration-widget)
- [Toss JavaScript SDK](https://docs.tosspayments.com/sdk/v2/js)
- [Toss confirm API](https://docs.tosspayments.com/reference)

## Lemon Setup

Create a webhook in Lemon Squeezy that points to:

```text
https://your-chargecat-api.example.com/webhooks/lemon
```

Subscribe at minimum to:

- `license_key_created`
- `order_created`

Use the same webhook signing secret in Lemon and `LEMON_WEBHOOK_SECRET`.

## Downloadable Asset Packs

- The app reads `GET /api/assets/catalog` to show downloadable Pro animation packs.
- Actual downloads flow through `GET /api/assets/download/:assetId`, and the backend verifies that the requester has an active Pro license on this Mac before serving the file.
- Put actual files in `backend/assets/files/`.
- Add each pack to `backend/assets/catalog.json`.
- Each item may use either:
  - `filename`: served by this backend after Pro validation
  - `downloadURL`: absolute URL if you want the backend to proxy another file host after Pro validation
- A starter example is documented in [backend/assets/README.md](/Users/coldmans/Documents/GitHub/chargeCat/backend/assets/README.md).

## Notes

- The backend currently uses Node's built-in `node:sqlite` module, which is available in Node 25 and still emits an experimental warning.
- Checkout sessions are installation-bound with `installationId`, so the app can auto-activate only for the Mac that started the checkout.
- Backend-issued licenses are stored separately from Lemon licenses and use the `ccp_` prefix.
- Toss checkout currently works best for instantly confirmed payment methods such as cards and easy-pay flows.
