# RideSync (assignment 1, project 2)

CS6.302 Software System Development

github: https://github.com/varun15103/2026201035_a1
final commit hash: (put this in before the moodle zip)

Ride-hailing db (like uber). postgres for riders/wallets/trips, mongo for vehicle extras, reviews and gps pings. no frontend.

## who is doing what

i did **step 1** (schema).

- **step 2**: trigger, partial index, materialized view, mongo collections + 2dsphere + TTL
  - `sql/02_indexes.sql`
  - `sql/03_triggers_and_audit.sql`
  - `sql/05_materialized_views.sql`
  - `mongo/01_collections_and_indexes.js`

- **step 3**: checkout procedure, window query, nearest vehicle, review stats
  - `sql/04_stored_procedures.sql`
  - `sql/06_window_analytics.sql`
  - `mongo/02_workflow3_geonear.js`
  - `mongo/03_workflow4_facet.js`

- **later (together)**: fake data + explain plans
  - `data_generation/postgres_seeder.py`
  - `data_generation/mongo_seeder.py`
  - `performance/`

dont add new columns in your own files. tell me and we change `sql/01_schema_ddl.sql` and the erd.

## folders

- `sql/` — postgres. `01_schema_ddl.sql` is done. rest is step 2/3.
- `docs/` — erd picture and mongo document shapes
- `mongo/` — mongosh scripts (create collections/indexes, then geoNear and $facet)
- `data_generation/` — python scripts to insert a lot of dummy data (100k audits, 50k trips, 500k pings). we do not upload the actual data, only the scripts
- `performance/` — paste EXPLAIN output here after seeding

## same names for everyone

- ids: UUID in postgres, same id as a string in mongo
- trip status: `REQUESTED`, `IN_TRANSIT`, `COMPLETED`
- wallet `action_type`: `DEBIT`, `CREDIT`, `ESCROW`
- gps: `[longitude, latitude]` (lng first)
- timestamps: timestamptz in postgres, Date in mongo
- nearest vehicle uses `TelemetryPings.is_available = true`
- `vehicles.is_active` = car is in the fleet, not live gps

## assumptions

- postgres 13+, mongo 6+
- no extra escrow table. we deduct `wallet_balance`. if it would go below 0 the check constraint fails and the txn should rollback
- `wallet_audit_logs` is insert only. step 2 trigger writes to it
- `license_plate` is unique, class is MINI / SEDAN / SUV / XL
- every trip has a `vehicle_id`
- step 2 partial index (from the pdf):
  `CREATE UNIQUE INDEX idx_active_rider_trip ON trips (rider_id) WHERE status IN ('REQUESTED', 'IN_TRANSIT');`
  so one rider should not have two active trips
- materialized view = completed trips per vehicle (count + sum of fares). concurrent refresh needs a unique index on the view
- ping ttl is 2 hours so seed `created_at` has to be recent
- dummy gps around hyderabad (lng 78.3-78.6, lat 17.3-17.5)

## step 1

- postgres: `sql/01_schema_ddl.sql`
- erd: `docs/relational_erd.png`
- mongo shapes: `docs/mongo_schema_map.json`

```bash
psql -d ridesync -f sql/01_schema_ddl.sql
```

## setup

```bash
createdb ridesync
```

or docker:

```bash
docker run -d --name ridesync-pg -e POSTGRES_PASSWORD=ridesync -e POSTGRES_DB=ridesync -p 5432:5432 postgres:16
docker run -d --name ridesync-mongo -p 27017:27017 mongo:7
```

python (for seeders later):

```bash
python -m venv venv
venv/Scripts/activate
pip install -r requirements.txt
```

run in this order:

1. `psql -d ridesync -f sql/01_schema_ddl.sql`
2. `psql -d ridesync -f sql/02_indexes.sql`
3. `psql -d ridesync -f sql/03_triggers_and_audit.sql`
4. `psql -d ridesync -f sql/05_materialized_views.sql`
5. `mongosh ridesync mongo/01_collections_and_indexes.js`
6. `psql -d ridesync -f sql/04_stored_procedures.sql`
7. `python data_generation/postgres_seeder.py`
8. `python data_generation/mongo_seeder.py`
9. `psql -d ridesync -f sql/06_window_analytics.sql`
10. `mongosh ridesync mongo/02_workflow3_geonear.js`
11. `mongosh ridesync mongo/03_workflow4_facet.js`
12. refresh the materialized view, then save explain output in `performance/`

dont run the analytics before seeding, there will be nothing to query.

## explain plans (paste later, required)

workflow 2 (postgres `EXPLAIN ANALYZE`):

```
(paste from performance/postgres_explain_analyzes.txt)
```

workflow 3 (mongo `explain("executionStats")`):

```
(paste from performance/mongo_execution_stats.json)
```

workflow 4 (mongo `explain("executionStats")`):

```
(paste from performance/mongo_execution_stats.json)
```

## moodle

zip name: `<team_number_a1>.zip`, under 20mb.
do not put dumps, csv, venv, or __pycache__ in the zip.
this readme must have the github link (done) and the final commit hash (add at the end).
