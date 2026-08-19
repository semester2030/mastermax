# venues

**Purpose:** Provider-facing venue ops (CRUD-lite, calendar, block, pricing rules, media metadata, team/finance reads).  
**Owns:** venue mutations initiated by provider.  
**Does not own:** Stream upload binary (metadata only).  
**Tables:** venues, availability_overrides, rate_rules, venue_media.  
**Public interfaces:** /v1/provider/*.  
**Invariants:** every mutation tenancy-scoped; availability block in one TX with capacity.
