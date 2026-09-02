// RideSync project 2, step 2
// creates VehicleMetadata, TripReviews, TelemetryPings and the indexes the pdf asks for.
// shapes match docs/mongo_schema_map.json. run with: mongosh ridesync mongo/01_collections_and_indexes.js

db.createCollection("VehicleMetadata");
db.createCollection("TripReviews");
db.createCollection("TelemetryPings");

// one metadata doc per vehicle -> vehicle_id should be unique
db.VehicleMetadata.createIndex(
    { vehicle_id: 1 },
    { unique: true, name: "uniq_vehicle_id" }
);

// one review per trip -> trip_id should be unique
db.TripReviews.createIndex(
    { trip_id: 1 },
    { unique: true, name: "uniq_trip_id" }
);

// required: 2dsphere on location for geo queries (nearest vehicle, step 3)
db.TelemetryPings.createIndex(
    { location: "2dsphere" },
    { name: "geo_location" }
);

// required: TTL of 2 hours (7200s) on created_at so old pings get dropped automatically.
// this only works because created_at is stored as a real Date, not a string (see
// docs/mongo_schema_map.json and the seeder, later).
db.TelemetryPings.createIndex(
    { created_at: 1 },
    { expireAfterSeconds: 7200, name: "ttl_created_at" }
);

print("collections + indexes created");