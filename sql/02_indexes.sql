-- RideSync project 2, step 2
-- partial index: one rider can have at most one REQUESTED/IN_TRANSIT trip at a time.
-- postgres enforces this as a unique index scoped to the partial WHERE clause,
-- so completed trips don't collide with each other or with a later active trip.

CREATE UNIQUE INDEX idx_active_rider_trip
    ON trips (rider_id)
    WHERE status IN ('REQUESTED', 'IN_TRANSIT');