# notifications

**Purpose:** NotificationPort + stub adapter consuming outbox.  
**Owns:** notifications rows (status=stubbed).  
**Does not own:** real FCM (future adapter).  
**Delivery:** at-least-once via OutboxWorker.  
**Invariants:** stub failures do not roll back completed bookings (worker marks failed after retries).
