# Settlements

**Purpose:** Draft settlements with explicit receivable membership; pay-time revalidation; stub payout + ledger.  
**Owns:** settlements, settlement_items, payouts (stub_paid).  
**Eligibility:** `ReceivableEligibilityService` sets `eligible` + `eligible_at` after COMPLETED.  
**Period:** half-open `[period_start, period_end)` Asia/Riyadh on `eligible_at` (not check_in).  
**Pay:** revalidate snapshot under locks; mismatch → `stale` + 409; never silent recalc.  
**Events:** settlement.created, settlement.paid.  
**Invariants:** unique active membership; rowCount===N on receivable pay; one payout; balanced ledger.
