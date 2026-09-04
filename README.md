# RideSync

**Assignment 1, Project 2 — CS6.302 Software System Development**
**Group 26** 

GitHub: https://github.com/varun15103/Group26

RideSync is a ride-hailing database backend (Uber-style) with no frontend. It's a polyglot-persistence design:

- **PostgreSQL** — riders, drivers, vehicles, wallets, trips, and audit logs (the relational core, where integrity matters most)
- **MongoDB** — vehicle extras, ratings/reviews, and high-volume GPS telemetry pings (flexible/high-write data)

---

## Team responsibilities

| Step | Owner | Covers |
|---|---|---|
| Step 1 | Varun | Schema design (Postgres DDL, ERD, Mongo document shapes) |
| Step 2 | Supriyo | Trigger, partial index, materialized view, Mongo collections + 2dsphere + TTL indexes |
| Step 3 | Srivastan | Checkout stored procedure, window-function analytics query, nearest-vehicle geoNear, review stats facet |
| Later (together) | Everyone (Varun, Supriyo, Srivastan) | Fake data generation |

**Rule:** don't add new columns inside your own files — flag it, and we'll update `sql/01_schema_ddl.sql` and the ERD together so both sides stay in sync.

---

## Repo layout

```
sql/                schema, indexes, triggers, materialized views, stored procedures
docs/                ERD image + mongo_schema_map.json
mongo/                mongosh scripts (collections/indexes, geoNear workflow, $facet workflow)
data_generation/    python seeders (no generated data itself is committed)
performance/        EXPLAIN ANALYZE / explain("executionStats") output goes here after seeding
```

| File | Step | Purpose |
|---|---|---|
| `sql/01_schema_ddl.sql` | 1 | Core relational schema |
| `sql/02_indexes.sql` | 2 | Indexes incl. the partial unique index |
| `sql/03_triggers_and_audit.sql` | 2 | Wallet audit trigger |
| `sql/05_materialized_views.sql` | 2 | Completed-trips-per-vehicle materialized view |
| `mongo/01_collections_and_indexes.js` | 2 | Mongo collections, 2dsphere + TTL indexes |
| `sql/04_stored_procedures.sql` | 3 | Trip checkout procedure |
| `sql/06_window_analytics.sql` | 3 | Window-function analytics query |
| `mongo/02_workflow3_geonear.js` | 3 | Nearest available vehicle (geoNear) |
| `mongo/03_workflow4_facet.js` | 3 | Review stats ($facet) |
| `data_generation/postgres_seeder.py` | later | Seeds Postgres (riders, trips, wallet audit logs) |
| `data_generation/mongo_seeder.py` | later | Seeds Mongo (extras, reviews, GPS pings) |

---

## Shared conventions

- **IDs:** UUID in Postgres; the same value stored as a string in Mongo.
- **Trip status:** `REQUESTED`, `IN_TRANSIT`, `COMPLETED`.
- **Wallet `action_type`:** `DEBIT`, `CREDIT`, `ESCROW`.
- **GPS coordinates:** `[longitude, latitude]` — longitude first (GeoJSON order).
- **Timestamps:** `timestamptz` in Postgres, `Date` in Mongo.
- **Nearest-vehicle lookup** uses `TelemetryPings.is_available = true`.
- `vehicles.is_active` means the car is in the fleet — it says nothing about live GPS/availability.

---

## Design assumptions

- Postgres 13+, Mongo 6+.
- No separate escrow table — escrow amounts are deducted directly from `wallet_balance`. If a deduction would push the balance below 0, the check constraint fails and the transaction rolls back.
- `wallet_audit_logs` is insert-only; the step 2 trigger is the only thing that writes to it.
- `license_plate` is unique; vehicle `class` is one of `MINI`, `SEDAN`, `SUV`, `XL`.
- Every trip has a `vehicle_id` (no unassigned trips).
- A rider can only have one active trip at a time, enforced by a partial unique index:
  ```sql
  CREATE UNIQUE INDEX idx_active_rider_trip
    ON trips (rider_id)
    WHERE status IN ('REQUESTED', 'IN_TRANSIT');
  ```
- The materialized view aggregates completed trips per vehicle (count + fare sum); concurrent refresh requires a unique index on the view.
- GPS ping TTL is 2 hours, so seeded `created_at` values need to be recent or they'll expire before you can query them.
- Seeded GPS coordinates cluster around Hyderabad (lng 78.3–78.6, lat 17.3–17.5).

---

## Setup

**1. Clone and enter the repo.**

```bash
git clone https://github.com/varun15103/Group26.git
```

**2. Create and activate the conda environment:**

```bash
conda create -n ridesync python=3.11 -y
conda activate ridesync
pip install -r requirements.txt
```

**3. Start Postgres and Mongo (Docker):**

```bash
docker run -d --name ridesync-pg -e POSTGRES_PASSWORD=ridesync -e POSTGRES_DB=ridesync -p 5432:5432 postgres:16
docker run -d --name ridesync-mongo -p 27017:27017 mongo:7
sleep 5   # give them a moment to finish initializing
```

**4. Export connection settings** (so `psql` stops prompting for a password each time):

```bash
export PGHOST=localhost PGPORT=5432 PGDATABASE=ridesync PGUSER=postgres PGPASSWORD=ridesync
export MONGO_URI=mongodb://localhost:27017
export MONGO_DB=ridesync
```

---

## Run order

1. **Schema, indexes, triggers, materialized view:**
   ```bash
   psql -h localhost -U postgres -d ridesync -f sql/01_schema_ddl.sql
   psql -h localhost -U postgres -d ridesync -f sql/02_indexes.sql
   psql -h localhost -U postgres -d ridesync -f sql/03_triggers_and_audit.sql
   psql -h localhost -U postgres -d ridesync -f sql/05_materialized_views.sql
   ```
   (each prompts for the `ridesync` password unless `PGPASSWORD` is exported as above)

2. **Mongo collections and indexes:**
   ```bash
   mongosh ridesync mongo/01_collections_and_indexes.js
   ```

3. **Stored procedure:**
   ```bash
   psql -h localhost -U postgres -d ridesync -f sql/04_stored_procedures.sql
   ```

4. **Seed the data.** Full scale is 50k trips + 500k+ pings, which takes a while and uses real disk. Do a quick smoke test first to confirm everything wires up, then run the full seed once:
   ```bash
   # quick smoke test
   RIDESYNC_QUICK_SEED=1 python data_generation/postgres_seeder.py
   RIDESYNC_QUICK_SEED=1 python data_generation/mongo_seeder.py

   # full run, once you've confirmed it works
   python data_generation/postgres_seeder.py
   python data_generation/mongo_seeder.py
   ```

5. **Analytics workflows** (only after seeding — there's nothing to query before that):
   ```bash
   psql -h localhost -U postgres -d ridesync -f sql/06_window_analytics.sql
   mongosh ridesync mongo/02_workflow3_geonear.js
   mongosh ridesync mongo/03_workflow4_facet.js
   ```

6. **Refresh the materialized view and capture the Postgres explain plan:**
   ```bash
   psql -h localhost -U postgres -d ridesync -c "SELECT refresh_vehicle_trip_stats();"

   psql -h localhost -U postgres -d ridesync \
     -c "EXPLAIN ANALYZE $(cat sql/06_window_analytics.sql)" \
     > performance/postgres_explain_analyzes.txt
   ```
   Capture the Mongo `explain("executionStats")` output for workflows 3 and 4 the same way and save both into `performance/`.

7. **Cleanup when done:**
   ```bash
   docker stop ridesync-pg ridesync-mongo
   docker rm ridesync-pg ridesync-mongo
   conda deactivate
   ```

---

## PLANS

**Workflow 2 — Postgres `EXPLAIN ANALYZE`:**
```
                                                                      QUERY PLAN                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------
 Incremental Sort  (cost=8371.59..10838.01 rows=35404 width=96) (actual time=399.997..525.778 rows=18290 loops=1)
   Sort Key: moving_avg.trip_day, (dense_rank() OVER (?))
   Presorted Key: moving_avg.trip_day
   Full-sort Groups: 46  Sort Method: quicksort  Average Memory: 29kB  Peak Memory: 29kB
   Pre-sorted Groups: 46  Sort Method: quicksort  Average Memory: 42kB  Peak Memory: 42kB
   ->  WindowAgg  (cost=8361.44..9069.52 rows=35404 width=96) (actual time=398.549..477.394 rows=18290 loops=1)
         ->  Sort  (cost=8361.44..8449.95 rows=35404 width=88) (actual time=398.542..422.312 rows=18290 loops=1)
               Sort Key: moving_avg.trip_day, moving_avg.moving_avg_7day DESC
               Sort Method: quicksort  Memory: 1912kB
               ->  Subquery Scan on moving_avg  (cost=3739.16..5686.38 rows=35404 width=88) (actual time=112.550..363.707 rows=18290 loops=1)
                     ->  WindowAgg  (cost=3739.16..5332.34 rows=35404 width=88) (actual time=112.546..316.096 rows=18290 loops=1)
                           ->  GroupAggregate  (cost=3739.16..4624.26 rows=35404 width=56) (actual time=112.518..242.072 rows=18290 loops=1)
                                 Group Key: trips.vehicle_id, (date_trunc('day'::text, trips.created_at))
                                 ->  Sort  (cost=3739.16..3827.67 rows=35404 width=30) (actual time=112.503..159.316 rows=35396 loops=1)
                                       Sort Key: trips.vehicle_id, (date_trunc('day'::text, trips.created_at))
                                       Sort Method: quicksort  Memory: 3165kB
                                       ->  Seq Scan on trips  (cost=0.00..1064.10 rows=35404 width=30) (actual time=0.013..54.624 rows=35396 loops=1)
                                             Filter: ((status)::text = 'COMPLETED'::text)
                                             Rows Removed by Filter: 2561
 Planning Time: 0.551 ms
 Execution Time: 548.748 ms
(21 rows)
```

**Workflow 3 — Mongo `explain("executionStats")`:**
```
{
  "workflow3_geonear": null,
  "workflow4_facet": null
}
```