# booking

**Purpose:** Holds, booking state machine, cancel/refund orchestration.  
**Owns:** booking_holds, bookings, booking_items, booking_guests (via flow), refunds path.  
**Does not own:** Payments PSP, ledger posting rules (delegates), capacity math (inventory).  
**Tables:** booking_holds, bookings, booking_items, booking_guests, refunds.  
**Public API:** via consumer cancel/holds; admin refunds.  
**Emits:** hold.created, hold.expired, booking.cancelled, refund.*.  
**Consumes:** —  
**Dependencies:** inventory.CapacityService, ledger, payments.port, audit, outbox.  
**Invariants:** status only via BookingStateMachine; multi-night hold atomic; expiry vs webhook exclusive.
