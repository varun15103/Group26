# RideSync (assignment 1, project 2)

repo: 2026201035_a1

github: (add link after first push)
final commit hash: (add this before moodle submission)

## who is doing what

i did **step 1** (schema).

- **step 2** (other person): trigger, partial index, materialized view, mongo 2dsphere + TTL
  - `sql/02_indexes.sql`
  - `sql/03_triggers_and_audit.sql`
  - `sql/05_materialized_views.sql`
  - `mongo/01_collections_and_indexes.js`

- **step 3** (other person): stored procedure, window query, geoNear, $facet
  - `sql/04_stored_procedures.sql`
  - `sql/06_window_analytics.sql`
  - `mongo/02_workflow3_geonear.js`
  - `mongo/03_workflow4_facet.js`

data generation / explain plans we can do together after 2 and 3 are working.

if you need a new column, ping me and we change `sql/01_schema_ddl.sql` + the erd. dont just add random fields in your scripts.

## stuff we should all use the same way

- postgres ids are UUID. in mongo store them as strings
- trip status: `REQUESTED`, `IN_TRANSIT`, `COMPLETED`
- wallet action_type: `DEBIT`, `CREDIT`, `ESCROW`
- geojson: `[longitude, latitude]` (lng first, this is easy to mess up)
- timestamps: timestamptz in postgres, Date in mongo
- for nearest vehicle, use `TelemetryPings.is_available = true`. `vehicles.is_active` is just whether the car is in the fleet

## assumptions

- pg 13+ / mongo 6+
- no separate escrow table, we just debit wallet_balance. the check constraint should make the txn rollback if balance goes below 0
- audit table is insert-only. trigger in step 2 writes to it
- license_plate unique, vehicle class is MINI/SEDAN/SUV/XL
- trip always has a vehicle_id
- partial unique index in step 2 (from pdf):
  `CREATE UNIQUE INDEX idx_active_rider_trip ON trips (rider_id) WHERE status IN ('REQUESTED', 'IN_TRANSIT');`
  so when seeding dont give one rider two active trips
- materialized view = completed trips per vehicle (count + sum of fares). concurrent refresh needs a unique index on the view
- ttl on pings is 2 hours so seed data has to be recent or it disappears
- i was thinking of putting dummy gps around hyderabad (78.3-78.6, 17.3-17.5)

## step 1 files

- postgres: `sql/01_schema_ddl.sql`
- erd: `docs/relational_erd.png`
- mongo docs: `docs/mongo_schema_map.json`

```
psql -d ridesync -f sql/01_schema_ddl.sql
```

## setup

```
createdb ridesync
```

or docker:

```
docker run -d --name ridesync-pg -e POSTGRES_PASSWORD=ridesync -e POSTGRES_DB=ridesync -p 5432:5432 postgres:16
docker run -d --name ridesync-mongo -p 27017:27017 mongo:7
```

run order:

1. sql/01_schema_ddl.sql
2. sql/02_indexes.sql
3. sql/03_triggers_and_audit.sql
4. sql/05_materialized_views.sql
5. mongo/01_collections_and_indexes.js
6. sql/04_stored_procedures.sql
7. seeders
8. sql/06_window_analytics.sql
9. mongo/02_workflow3_geonear.js
10. mongo/03_workflow4_facet.js
11. refresh mv + save explain output in performance/

## explain (paste later)

### workflow 2 (postgres)

```
```

### workflow 3 (mongo)

```
```

### workflow 4 (mongo)

```
```

## moodle

zip should be `<team_number_a1>.zip`, under 20mb. no dumps, no venv, no csv.
remember to put the github url and last commit hash here.
