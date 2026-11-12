// Portfolio 4: indexes, built after the bulk load (faster than indexing during it).
// Each one matches a query in 04_document_queries.js.

db = db.getSiblingDB("marriott");

db.guests.createIndex({ email: 1 }, { unique: true });
db.guests.createIndex({ "bonvoy.member_number": 1 },
                      { unique: true, partialFilterExpression: { bonvoy: { $exists: true } } });

db.reservations.createIndex({ "guest.id": 1, check_in: -1 });   // a guest's booking history
db.reservations.createIndex({ "hotel.code": 1, check_in: 1 });  // a hotel's arrivals

db.hotels.createIndex({ "location.country": 1, "brand.name": 1 });

print("indexes:");
["hotels", "guests", "reservations"].forEach(c =>
  db[c].getIndexes().forEach(i => print("  " + c + "." + i.name)));
