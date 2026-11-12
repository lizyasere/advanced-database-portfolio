// Portfolio 4: room availability as a key-value store.
// docker exec marriott_mongo mongosh --quiet /scripts/p4/05_availability_kv.js
//
// Searching for a room is far more common than booking one, so the availability check
// should be a single key lookup, not a query over all bookings. This is the kind of
// workload Marriott moved off its mainframe onto a NoSQL database.

load("/scripts/p4/kv_book.js");
db = db.getSiblingDB("marriott");

print("=== 1. Build the availability keys for Lagos Marriott Ikeja, 20 to 31 Dec 2027 ===");
db.availability.drop();
const hotel = db.hotels.findOne({ _id: "LOSMC" });
const docs = [];
for (const rt of hotel.room_types) {
  for (let day = 20; day <= 31; day++) {
    const night = new Date(Date.UTC(2027, 11, day));
    const sold = db.reservations.countDocuments({
      "hotel.code": "LOSMC", "room_type.code": rt.code,
      status: { $in: ["Confirmed", "Checked In"] },
      check_in: { $lte: night }, check_out: { $gt: night } });
    docs.push({ _id: `LOSMC|${rt.code}|${night.toISOString().slice(0, 10)}`, total: rt.rooms, sold: sold });
  }
}
db.availability.insertMany(docs);
print(`${docs.length} keys created (${hotel.room_types.length} room types x 12 nights)`);
db.availability.find({ _id: /^LOSMC\|EXSU\|2027-12-2[3-7]/ }).sort({ _id: 1 })
  .forEach(d => print(`  ${d._id}  total ${d.total}  sold ${d.sold}  free ${d.total - d.sold}`));

print("\n=== 2. Availability check is a single key lookup ===");
const ex = db.availability.find({ _id: "LOSMC|EXSU|2027-12-24" }).explain("executionStats").executionStats;
print(`plan: ${ex.executionStages.stage} | keys examined ${ex.totalKeysExamined}, docs examined ${ex.totalDocsExamined}`);

print("\n=== 3. Book the last Executive Suite for 24 to 27 Dec (3 nights) ===");
printjson(book("LOSMC", "EXSU", new Date(Date.UTC(2027, 11, 24)), 3));

print("\n=== 4. The next guest asks for the same nights ===");
printjson(book("LOSMC", "EXSU", new Date(Date.UTC(2027, 11, 24)), 3));

print("\n=== 5. A stay of 22 to 26 Dec: the first two nights are free, the 24th is full ===");
print("before: " + db.availability.find({ _id: /^LOSMC\|EXSU\|2027-12-2[23]/ }).toArray()
  .map(d => d._id.slice(-5) + " sold " + d.sold).join(", "));
printjson(book("LOSMC", "EXSU", new Date(Date.UTC(2027, 11, 22)), 4));
print("after:  " + db.availability.find({ _id: /^LOSMC\|EXSU\|2027-12-2[23]/ }).toArray()
  .map(d => d._id.slice(-5) + " sold " + d.sold).join(", ") + "  (nights given back)");
