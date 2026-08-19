# Places Provider Web — Wave1 (internal staging)

Arabic RTL / light-theme Next.js app for the DAR CAR internal Places operator.

## Stack

- Next.js 16 App Router + React 19 + TypeScript
- Tailwind CSS 4 + purple DAR CAR tokens (from `website`)
- Places Core HTTP API only (`PLACES_API_BASE_URL`) — **no mock data**

## Setup

```bash
cd apps/places-provider-web
cp .env.example .env.local
# set PLACES_API_BASE_URL to your Core instance
npm install
npm run dev   # http://127.0.0.1:3010
```

## Env (see `.env.example`)

| Variable | Notes |
|---|---|
| `PLACES_API_BASE_URL` | Core base URL (server-only) |
| `PLACES_PROVIDER_WEB_ORIGIN` | App origin (documentation / CORS alignment) |
| `NEXT_PUBLIC_APP_NAME` | Optional display title only |

**Never** put `PLACES_OTP_FIXED_CODE_SECRET`, `DAR_CAR_INTERNAL_OPERATOR_PHONE`, or phone allowlists in this app’s env or logs. Core owns those secrets.

## Auth

1. User enters phone on `/login`
2. Next proxies `POST /v1/auth/internal/otp/send` to Core
3. User enters OTP → Next verifies via Core and stores JWT in **httpOnly** cookie (`places_provider_session`)
4. Middleware guards all routes except `/login` and `/api/auth/*`
5. `providerId` comes from JWT claim `onBehalfOfProviderId`

## Scripts

- `npm run dev` — port **3010**
- `npm run build`
- `npm run lint`
- `npm run typecheck`
- `npm run test`

## Wave1 screens

- `/` dashboard KPIs
- `/venues`, `/venues/new`, `/venues/[id]` (+ units / pricing / availability / media)
- `/bookings`, `/bookings/[id]` (+ cancel)

See `docs/places_provider_web_wave1/KNOWN_ISSUES.md` for Core gaps (GET venues/media/rate-plans, event-slot kill switch).
