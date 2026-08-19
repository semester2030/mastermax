# ledger

**Purpose:** Append-only paired journal.  
**Owns:** ledger_entries inserts via postGroup.  
**Invariants:** debit==credit per group; no UPDATE/DELETE (trigger).  
**Does not own:** Settlements payout bank rails.
