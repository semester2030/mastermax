# providers

**Purpose:** Provider tenancy membership and permission checks.  
**Owns:** provider membership resolution (reads provider_users).  
**Does not own:** venue CRUD, finance math.  
**Tables:** providers, provider_users, provider_roles (read).  
**Public interfaces:** TenancyService.require / requireAny.  
**Events:** none.  
**Dependencies:** PgService, RBAC matrix.  
**Invariants:** client-supplied providerId never trusted without membership.
