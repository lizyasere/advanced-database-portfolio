// Portfolio 4: queries on the document model.
// docker exec marriott_mongo mongosh --quiet /scripts/p4/04_document_queries.js

db = db.getSiblingDB("marriott");
const EMAIL = "Layla.Chen63452@example.net";   // Bonvoy member with 17 bookings

function title(t) { print("\n=== " + t + " ==="); }
function plan(cursor) {
  const s = cursor.explain("executionStats").executionStats;
  const stages = [];
  let st = s.executionStages;
  while (st) { stages.push(st.stage + (st.indexName ? "(" + st.indexName + ")" : "")); st = st.inputStage; }
  print(`plan: ${stages.join(" <- ")} | keys examined ${s.totalKeysExamined}, ` +
        `docs examined ${s.totalDocsExamined}, returned ${s.nReturned}, ${s.executionTimeMillis} ms`);
}

title("1. Guest profile screen: profile, Bonvoy account and recent bookings in one read");
printjson(db.guests.findOne({ email: EMAIL }));
plan(db.guests.find({ email: EMAIL }));

title("2. Full booking history for the same guest, newest first");
const guestId = db.guests.findOne({ email: EMAIL })._id;
db.reservations.find({ "guest.id": guestId },
                     { _id: 1, "hotel.name": 1, check_in: 1, nights: 1, status: 1 })
  .sort({ check_in: -1 }).limit(5)
  .forEach(r => print(`  ${r._id}  ${r.check_in.toISOString().slice(0, 10)}  ${r.nights} nights  ${r.status.padEnd(11)}  ${r.hotel.name}`));
print("  ...");
plan(db.reservations.find({ "guest.id": guestId }).sort({ check_in: -1 }));

title("3. Flexible schema: hotels in Lagos, each brand has different features");
db.hotels.find({ "location.city": "Lagos" }, { name: 1, "brand.tier": 1, features: 1 })
  .sort({ _id: 1 }).limit(6)
  .forEach(h => print(`  ${h._id}  ${h.brand.tier.padEnd(13)} ${JSON.stringify(h.features)}`));
print("hotels with a spa: " + db.hotels.countDocuments({ "features.spa": true }) +
      ", hotels with weekly rates: " + db.hotels.countDocuments({ "features.weekly_rates": true }) +
      ", hotels with backup power: " + db.hotels.countDocuments({ "features.backup_power": { $exists: true } }));

title("4. Room nights sold by brand in the last 12 months (aggregation pipeline)");
db.reservations.aggregate([
  { $match: { status: "Checked Out",
              check_in: { $gte: ISODate("2025-11-12"), $lt: ISODate("2026-11-12") } } },
  { $group: { _id: "$hotel.brand",
              stays: { $sum: 1 },
              room_nights: { $sum: "$nights" } } },
  { $sort: { room_nights: -1 } }
]).forEach(r => print(`  ${r._id.padEnd(17)} ${String(r.stays).padStart(7)} stays  ${String(r.room_nights).padStart(8)} room nights`));

title("5. Adding a payment touches only one document, so it is atomic on its own");
const conf = db.reservations.findOne({ "guest.id": guestId, status: "Confirmed" })._id;
print("booking " + conf + " payments before: " + (db.reservations.findOne({ _id: conf }).payments || []).length);
db.reservations.updateOne({ _id: conf }, { $push: { payments: {
  amount: NumberDecimal("50000.00"), currency: "NGN", method: "Card", card_last4: "4417",
  status: "Authorised", paid_at: new Date() } } });
print("booking " + conf + " payments after:  " + db.reservations.findOne({ _id: conf }).payments.length);
db.reservations.updateOne({ _id: conf }, { $pop: { payments: 1 } });   // put it back

title("6. Validation rules still apply");
try {
  db.reservations.insertOne({ _id: "P4BAD1", guest: { id: guestId }, hotel: { code: "LOSMC" },
    room_type: { code: "DLXK" }, check_in: ISODate("2027-01-10"), check_out: ISODate("2027-01-10"),
    nights: 0, nightly_rate: NumberDecimal("180000"), status: "Pending" });
  print("inserted (should not happen)");
} catch (e) {
  print("rejected: " + e.errInfo.details.schemaRulesNotSatisfied[0].propertiesNotSatisfied
        .map(p => p.propertyName).join(", ") + " broke the rules");
}
db.reservations.insertOne({ _id: "P4NEW1", guest: { id: guestId }, hotel: { code: "LOSMC" },
  room_type: { code: "DLXK" }, check_in: ISODate("2027-01-10"), check_out: ISODate("2027-01-12"),
  nights: 2, nightly_rate: NumberDecimal("180000"), status: "Confirmed",
  special_requests: ["late check-in", "high floor"] });
print("accepted: P4NEW1 with a new field (special_requests) that no other booking has");
db.reservations.deleteOne({ _id: "P4NEW1" });
