// step 2
// create VehicleMetadata, TripReviews, TelemetryPings (see docs/mongo_schema_map.json)
// 2dsphere on TelemetryPings.location
// TTL on created_at, expireAfterSeconds: 7200
// coords are [lng, lat]
