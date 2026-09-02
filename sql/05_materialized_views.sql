-- RideSync project 2, step 2
-- materialized view: every vehicle with its lifetime completed-trip count and total earnings.
-- LEFT JOIN so vehicles with zero completed trips still show up, with 0 / 0.00 instead of
-- disappearing.

CREATE MATERIALIZED VIEW mv_vehicle_trip_stats AS
SELECT
    v.id                                                              AS vehicle_id,
    v.license_plate,
    v.class,
    COUNT(t.id)      FILTER (WHERE t.status = 'COMPLETED')            AS completed_trip_count,
    COALESCE(SUM(t.fare_amount) FILTER (WHERE t.status = 'COMPLETED'), 0.00)
                                                                       AS total_earnings
FROM vehicles v
LEFT JOIN trips t ON t.vehicle_id = v.id
GROUP BY v.id, v.license_plate, v.class
WITH DATA;

-- REFRESH ... CONCURRENTLY requires a unique index on the view (so postgres can diff
-- old vs new rows instead of locking readers out). one row per vehicle_id, so this works.
CREATE UNIQUE INDEX idx_mv_vehicle_trip_stats_vehicle_id
    ON mv_vehicle_trip_stats (vehicle_id);

-- wrapper function so callers/cron don't need to remember the CONCURRENTLY keyword.
-- note: the view is created WITH DATA above (0 rows is fine) specifically so this works
-- the very first time it's called, before any seed data exists.
CREATE OR REPLACE FUNCTION refresh_vehicle_trip_stats()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_trip_stats;
END;
$$ LANGUAGE plpgsql;