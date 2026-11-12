// Portfolio 4: create the MongoDB collections with validation rules, then the indexes.
// docker exec marriott_mongo mongosh --quiet /scripts/p4/01_create_collections.js
//
// MongoDB does not force a schema, but a collection can still reject bad documents.
// The rules below only cover the fields every document must have; anything else
// (for example the hotel "features" object) is free to vary.

db = db.getSiblingDB("marriott");
db.dropDatabase();

db.createCollection("hotels", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "name", "brand", "location", "currency", "room_types"],
    properties: {
      _id:         { bsonType: "string", minLength: 5, maxLength: 5, description: "MARSHA code" },
      star_rating: { bsonType: "int", minimum: 1, maximum: 5 },
      currency:    { bsonType: "string", minLength: 3, maxLength: 3 },
      room_types: {
        bsonType: "array", minItems: 1,
        items: {
          bsonType: "object",
          required: ["code", "name", "max_occupancy", "base_rate"],
          properties: {
            max_occupancy: { bsonType: "int", minimum: 1 },
            base_rate:     { bsonType: "decimal" }
          }
        }
      }
    }
  }}
});

db.createCollection("guests", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "name", "email"],
    properties: {
      email: { bsonType: "string", pattern: "^[^@\\s]+@[^@\\s]+$" },
      bonvoy: {
        bsonType: "object",
        required: ["member_number", "tier", "points_balance"],
        properties: {
          tier: { enum: ["Member", "Silver Elite", "Gold Elite", "Platinum Elite", "Titanium Elite", "Ambassador Elite"] },
          points_balance: { bsonType: "int", minimum: 0 }
        }
      },
      recent_bookings: { bsonType: "array", maxItems: 3 }
    }
  }}
});

db.createCollection("reservations", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "guest", "hotel", "room_type", "check_in", "check_out", "nights", "nightly_rate", "status"],
    properties: {
      check_in:     { bsonType: "date" },
      check_out:    { bsonType: "date" },
      nights:       { bsonType: "int", minimum: 1 },
      nightly_rate: { bsonType: "decimal" },
      status:       { enum: ["Confirmed", "Checked In", "Checked Out", "Cancelled", "No Show"] },
      payments:     { bsonType: "array" }
    }
  }}
});

print("collections created: " + db.getCollectionNames().sort().join(", "));
