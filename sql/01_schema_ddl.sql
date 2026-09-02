-- RideSync project 2, step 1
-- postgres tables from the assignment. dont add extra columns without telling me.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- wallet cant go negative, checkout in step 3 should fail if they dont have money
CREATE TABLE riders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    wallet_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00
        CHECK (wallet_balance >= 0.00)
);

-- step 2 will put a trigger on riders that inserts here whenever balance changes
CREATE TABLE wallet_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id UUID NOT NULL REFERENCES riders(id),
    amount_changed DECIMAL(10,2) NOT NULL,
    action_type VARCHAR(16) NOT NULL
        CHECK (action_type IN ('DEBIT', 'CREDIT', 'ESCROW')),
    balance_after DECIMAL(10,2) NOT NULL CHECK (balance_after >= 0.00),
    "timestamp" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- class values we agreed on (not in pdf, just so seed data is consistent)
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_plate VARCHAR(32) NOT NULL UNIQUE,
    class VARCHAR(32) NOT NULL CHECK (class IN ('MINI', 'SEDAN', 'SUV', 'XL')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- vehicle_id not null, so book the vehicle first then insert the trip
-- status: REQUESTED, IN_TRANSIT, COMPLETED
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id UUID NOT NULL REFERENCES riders(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    fare_amount DECIMAL(10,2) NOT NULL CHECK (fare_amount >= 0.00),
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('REQUESTED', 'IN_TRANSIT', 'COMPLETED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
