# Places Core

Independent DAR CAR Places booking engine (Gate 3).

- NestJS + TypeScript + PostgreSQL
- Path: `services/places-core/`
- Official product reference: `docs/places_amaken/`

```
cp .env.example .env
# set DATABASE_URL
npm install
npm run migrate
npm test
npm run start:dev
```

`AUTH_MODE=stub` uses `Authorization: Bearer stub.<uid>.<claims>`.
Production uses `AUTH_MODE=firebase`.
PaymentPort is the documented stub until OD-PSP.
