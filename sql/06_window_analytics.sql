-- RideSync project 2, step 3
-- Workflow 2: for each vehicle, the 7-day trailing moving average of daily completed-trip
-- revenue, with vehicles ranked by that moving average within each day via DENSE_RANK().
-- (DENSE_RANK so tied moving averages share a rank with no gap in the sequence.)
--
-- Depends on: sql/01_schema_ddl.sql (trips.vehicle_id, fare_amount, status, created_at).
-- Run only after seeding -- with no COMPLETED trips this just returns 0 rows.

WITH daily_revenue AS (
    -- one row per vehicle per calendar day it had completed-trip revenue
    SELECT
        vehicle_id,
        date_trunc('day', created_at) AS trip_day,
        SUM(fare_amount)              AS daily_fare
    FROM trips
    WHERE status = 'COMPLETED'
    GROUP BY vehicle_id, date_trunc('day', created_at)
),
moving_avg AS (
    SELECT
        vehicle_id,
        trip_day,
        daily_fare,
        -- trailing 7-day window (today + 6 days back), scoped per vehicle.
        -- RANGE (not ROWS) so a vehicle with a gap-day still averages over the
        -- correct calendar window rather than just "the last 7 rows it has".
        ROUND(
            AVG(daily_fare) OVER (
                PARTITION BY vehicle_id
                ORDER BY trip_day
                RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
            ),
        2) AS moving_avg_7day
    FROM daily_revenue
)
SELECT
    trip_day,
    vehicle_id,
    daily_fare,
    moving_avg_7day,
    -- rank vehicles against each other within the same day, best moving average first
    DENSE_RANK() OVER (
        PARTITION BY trip_day
        ORDER BY moving_avg_7day DESC
    ) AS revenue_rank
FROM moving_avg
ORDER BY trip_day, revenue_rank;
