# DAR CAR — Map Listing Cardinality Baseline

**PR-004 · Epic A Protect · RK-018 (preparation) · EV-038 · EV-154**  
**PR-022 update:** N2 measured; `MAP_BOUNDED_FETCH` + cars limit documented  
**Status:** Official baseline + N2 measurement record  
**Date:** 2026-07-20 (baseline) · N2 measured 2026-07-21  
**Firebase project:** `mastermax-2030-backend` (`.firebaserc`)

---

## Explicit statement

**PR-004:** documentation only (no runtime change).  
**PR-022:** `CarService.getCars` may apply `.limit(500)` **only** when compile-time
`MAP_BOUNDED_FETCH=true` (default **false** — production remains unbounded).

---

## 1. Purpose

Establish the official **N baseline** for production map datasets before any bounded-fetch work:

| Future PR | Intent | Depends on this doc |
|-----------|--------|---------------------|
| **PR-022** | `MAP_BOUNDED_FETCH` + limit on `getCars` | Real `cars` active count (N2) — **DONE** |
| **PR-023** | bounded fetch on `getProperties` | Real `properties` count / available subset (N3/N4) |

Without measured N, any hardcoded limit risks hiding listings (MEP: “حد بلا N = إخفاء إعلانات”).

---

## 2. Current loading strategy (repository evidence)

### 2.1 Map entry path

| Step | Location | Behavior |
|------|----------|----------|
| Map init | `lib/src/features/map/screens/main_map_screen.dart` → `_loadInitialData()` | Parallel `propertyProvider.loadProperties()` + `carProvider.loadCars()` |
| Push into map state | `_updateMapData(...)` | `MapState.updateProperties` + `updateVisibleCars` with **full lists** |
| Filter re-fetch | same screen (property filters) | May call `propertyProvider.service.getProperties(...)` again |

Evidence (load + unbounded pass-through):

- EV-154 — map loads cars+properties with no limit, then passes all to `MapState`
- `main_map_screen.dart` ≈ L186–225

### 2.2 Cars

| Item | Evidence |
|------|----------|
| Collection | `cars` |
| Service | `lib/src/features/cars/services/car_service.dart` → `getCars()` |
| Server filter | `where('isActive', isEqualTo: true)` |
| `.limit(...)` | **None by default.** When `AppConfig.mapBoundedFetch == true`, `.limit(500)` (PR-022). Default compile-time flag: **false**. |
| Provider | `CarProvider.loadCars()` → `CarService.getCars()` |
| Feature flag | `MAP_BOUNDED_FETCH` → `AppConfig.mapBoundedFetch` via `--dart-define=MAP_BOUNDED_FETCH=true` |

### 2.3 Properties

| Item | Evidence |
|------|----------|
| Collection | `properties` |
| Service | `lib/src/features/properties/services/property_service.dart` → `getProperties()` |
| Server filter (map default) | Full collection `query.get()` (optional `ownerId` only when provided) |
| Client filters | type, price, rooms, location, availability — **after** full fetch |
| `.limit(...)` | **None** (EV-040 / EV-154) — pending PR-023 |
| Provider | `PropertyProvider.loadProperties()` → `getProperties(ownerId: …)` |

### 2.4 Other datasets on the map?

| Dataset | Used as bulk map pins? | Notes |
|---------|------------------------|-------|
| `cars` | **Yes** | Primary map dataset |
| `properties` | **Yes** | Primary map dataset |
| Spotlight / videos | **No bulk load** | `VideoModel` may move camera to a location when passed via route args; not a full-collection map fetch |
| CRM collections (sales, rentals, …) | **No** | Not part of `MainMapScreen` initial load |

**Map cardinality scope for PR-022/023 = `cars` + `properties` only.**

---

## 3. Current known datasets (qualitative)

| Dataset | Firestore collection | Map-relevant subset | Cardinality status |
|---------|----------------------|---------------------|--------------------|
| Cars (active) | `cars` | `isActive == true` | **N2 = 32** (exact, 2026-07-21) |
| Cars (all docs) | `cars` | all documents | **N1 = 39** (exact, same session) |
| Properties (all docs) | `properties` | what map loads today (unbounded) | **MEASUREMENT_REQUIRED** |
| Properties (available / active-like) | `properties` | client `PropertyStatus.available` when filtered | **MEASUREMENT_REQUIRED** |

---

## 4. Known measurements

| Metric | Value | Source |
|--------|-------|--------|
| Unbounded `getCars` (active) | Confirmed in code (flag OFF) | `car_service.dart` |
| Bounded `getCars` when flag ON | `.limit(500)` | PR-022 / `AppConfig.mapBoundedFetchCarsLimit` |
| Unbounded `getProperties` | Confirmed in code | `property_service.dart` |
| Map loads both lists fully into state | Confirmed in code | `main_map_screen.dart` |
| Production **N2** (`cars` `isActive == true`) | **32** (exact) | Firestore COUNT aggregation · see §5 |
| Production **N1** (`cars` total) | **39** (exact) | Same session |
| Production `N_properties` | **MEASUREMENT_REQUIRED** | Pending PR-023 prep |

---

## 5. Measured values

| ID | Metric | Definition | Status / Value |
|----|--------|------------|----------------|
| N1 | `cars` total documents | `cars` collection size | **39** (exact) |
| N2 | `cars` active | `isActive == true` (same filter as `getCars`) | **32** (exact) |
| N3 | `properties` total documents | Full collection (same as default map fetch) | MEASUREMENT_REQUIRED |
| N4 | `properties` available | Docs matching map “available” semantics if used for limit design | MEASUREMENT_REQUIRED |
| N5 | Measurement timestamp (UTC) | When N1–N2 were taken | **2026-07-21T01:13:33 UTC** |
| N6 | Measurement method | COUNT aggregation | Firestore REST `runAggregationQuery` (exact COUNT) |
| N7 | Measurer | Agent session (PR-022 preparation) | PR-022 prep |

### Official N2 record (PR-022 basis)

```text
Measured at (UTC): 2026-07-21T01:13:33Z
Method: Exact COUNT aggregation (Firestore REST runAggregationQuery)
Project: mastermax-2030-backend
Database: (default)
Query: cars where isActive == true
N_cars_total (N1): 39
N_cars_isActive_true (N2): 32
N_properties_total: MEASUREMENT_REQUIRED
N_properties_available: MEASUREMENT_REQUIRED
Approved initial MAP_BOUNDED_FETCH limit: 500
Notes: Flag default false — production stays unbounded until explicitly enabled via dart-define.
```

---

## 6. Known limitations

- Soft CI / unit tests do not assert production cardinality.
- Emulator data ≠ production N.
- Properties “active” semantics differ from cars (`isActive` vs `PropertyStatus` client filter).
- Re-measure N2 before raising or enabling the production flag if inventory approaches ~80% of 500 (~400 active cars).

---

## 7. Repository evidence index

| EV / RK | Claim |
|---------|--------|
| EV-038 | `CarService.getCars` — `isActive` + unbounded `get()` (default) |
| EV-040 | `PropertyService.getProperties` — unbounded `get()` + client filters |
| EV-154 | Map loads cars+properties unbounded into `MapState` |
| RK-018 | Unbounded map fetch — remediation PR-022 (cars, behind flag) / PR-023 (properties) |

Governance portals: production readiness · master execution plan · this SSOT log.

---

## 8. Future measurements required

1. Authenticated **read-only** aggregate counts on production for **N3–N4** (properties).  
2. Re-measure N2 at least quarterly or before changing the 500 limit / enabling the flag in store builds.  
3. Optionally attach a Console screenshot path under `docs/metrics/` (docs only).

---

## 9. Preparation for PR-022 (cars limit flag)

- [x] Fill **N2** (`cars` where `isActive == true`) → **32**  
- [x] Choose limit relative to N2 → **500** (~15× headroom)  
- [x] Confirm flag default **off** until Observe plan exists → `MAP_BOUNDED_FETCH` default **false**  
- [x] Do not ship limit enabled in production builds (no dart-define in release CI)

---

## 10. Preparation for PR-023 (properties limit flag)

Before implementing `getProperties` bounded fetch:

- [ ] Fill **N3** (and **N4** if limit targets “available” only)  
- [ ] Align server-side filter with today’s client semantics (avoid silent drop)  
- [ ] Merge only after PR-022 Observe (per MEP)  
- [ ] Keep Rules / Auth / Maps keys work out of that PR  

---

## 11. Rollback

- Docs: revert this file’s N2 / PR-022 sections if needed.  
- Code: revert PR-022 commit, or keep flag at default `false` (no production behavior change).

---

## 12. Compliance checklist (PR-004 + PR-022 measurement)

- [x] N2 recorded from exact production COUNT (not invented)  
- [x] Project / timestamp / query documented  
- [x] Approved limit 500 recorded  
- [x] Flag default false (production not enabled)  
- [ ] N3/N4 still MEASUREMENT_REQUIRED (PR-023)  
