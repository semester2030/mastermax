# payments

**Purpose:** Payment intents + webhook SoT confirmation.  
**Owns:** payments, payment_attempts, webhook_events (processing).  
**Does not own:** Real PSP (OD-PSP stub).  
**Public API:** POST /v1/payments/intents, POST /v1/webhooks/psp/:psp.  
**Emits:** booking.confirmed, payment.failed (via SM/outbox).  
**Invariants:** One TX for confirm+ledger+inventory; late pay → refunded_after_expiry; HMAC+skew.
