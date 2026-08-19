# inventory

**Purpose:** Daily capacity buckets and mutations.  
**Owns:** inventory_daily_capacity mutations.  
**Invariants:** FOR UPDATE; rowCount checks; held+booked+blocked ≤ capacity (CHECK).  
**API:** none direct — used by hold/payment/refund/provider block.
