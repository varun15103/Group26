// RideSync project 2, step 3
// Workflow 4: one pipeline, three facets computed off the same TripReviews match set --
// rating distribution, most frequent feedback tags (via $unwind), overall average rating.
//
// Depends on: docs/mongo_schema_map.json shape for TripReviews (rating, tags[], vehicle_id).
//
// Scoped to a single vehicle by default since "review stats" is most useful per-vehicle;
// drop the $match stage (or pass an empty {}) to run it fleet-wide instead.

const vehicleId = "c3a91f2e-6b14-4d08-9e7a-21b0c84d5f33"; // swap for a real vehicle_id

db.TripReviews.aggregate([
    { $match: { vehicle_id: vehicleId } },
    {
        $facet: {
            rating_distribution: [
                { $group: { _id: "$rating", count: { $sum: 1 } } },
                { $sort: { _id: 1 } }
            ],
            top_feedback_tags: [
                { $unwind: "$tags" },
                { $group: { _id: "$tags", count: { $sum: 1 } } },
                { $sort: { count: -1 } },
                { $limit: 5 },
                { $project: { _id: 0, tag: "$_id", count: 1 } }
            ],
            overall_average_rating: [
                {
                    $group: {
                        _id: null,
                        average_rating: { $avg: "$rating" },
                        review_count: { $sum: 1 }
                    }
                },
                { $project: { _id: 0, average_rating: 1, review_count: 1 } }
            ]
        }
    }
]);