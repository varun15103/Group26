-- RideSync project 2, step 3
-- Workflow 1: atomic booking. Moves fare_amount out of the rider's wallet_balance
-- (logged as ESCROW via the step-2 trigger flag), then inserts the trip. If the
-- wallet CHECK constraint (balance >= 0) fails, the whole call rolls back
-- automatically -- no trip row gets created and no partial state is left behind.
--
-- Depends on:
--   sql/01_schema_ddl.sql   -- riders.wallet_balance CHECK, trips table
--   sql/02_indexes.sql      -- idx_active_rider_trip (blocks a 2nd active trip for the rider)
--   sql/03_triggers_and_audit.sql -- trg_wallet_audit_log reads ridesync.wallet_action_type
--
-- Usage (must be called as a top-level CALL, not inside an existing multi-statement
-- transaction block, since this procedure issues its own COMMIT):
--   CALL book_trip('<rider_uuid>', '<vehicle_uuid>', 250.00, NULL);

CREATE OR REPLACE PROCEDURE book_trip(
    p_rider_id    UUID,
    p_vehicle_id  UUID,
    p_fare_amount DECIMAL(10,2),
    INOUT p_trip_id UUID DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- tag the upcoming wallet_balance decrease as ESCROW (not a plain DEBIT) for
    -- the step-2 audit trigger. SET LOCAL/is_local so it only applies to this
    -- transaction and never leaks onto a pooled connection.
    SET LOCAL ridesync.wallet_action_type = 'ESCROW';

    -- move the fare into escrow. if this would take wallet_balance below 0, the
    -- CHECK constraint on riders raises check_violation right here, before the
    -- trip is ever inserted, and the whole CALL rolls back automatically.
    UPDATE riders
    SET wallet_balance = wallet_balance - p_fare_amount
    WHERE id = p_rider_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'book_trip: rider % not found', p_rider_id;
    END IF;

    -- idx_active_rider_trip (partial unique index, step 2) will reject this insert
    -- if the rider already has a REQUESTED/IN_TRANSIT trip -- same rollback behavior.
    INSERT INTO trips (rider_id, vehicle_id, fare_amount, status)
    VALUES (p_rider_id, p_vehicle_id, p_fare_amount, 'REQUESTED')
    RETURNING id INTO p_trip_id;

    COMMIT;
END;
$$;
