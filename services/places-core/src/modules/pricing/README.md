# pricing

**Purpose:** Deterministic quote computation and immutable quote persistence.  
**Owns:** quotes, quote_items (via QuoteService); rate rule evaluation.  
**Does not own:** holds, payments.  
**Tables:** rate_plans, rate_rules, extras, promo_codes, quotes, quote_items.  
**Priority:** date_range > weekend/weekday > base; then extras/promo.  
**Events:** quote.created.  
**Invariants:** commission snapshot stored on quote/booking; money via Decimal cents.
