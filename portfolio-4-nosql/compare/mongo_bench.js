// the same three screens in MongoDB, timed inside mongosh
db = db.getSiblingDB("marriott");
const tests = {
  baseline:     () => db.runCommand({ ping: 1 }),   // empty command: client and round trip only
  profile:      () => db.guests.findOne({ email: "Layla.Chen63452@example.net" }),
  booking:      () => db.reservations.findOne({ _id: "90485359" }),
  brand_nights: () => db.reservations.aggregate([
    { $match: { status: "Checked Out", check_in: { $gte: ISODate("2025-11-12"), $lt: ISODate("2026-11-12") } } },
    { $group: { _id: "$hotel.brand", stays: { $sum: 1 }, room_nights: { $sum: "$nights" } } },
    { $sort: { room_nights: -1 } }]).toArray()
};
const runs = { baseline: 500, profile: 500, booking: 500, brand_nights: 5 };
for (const [name, fn] of Object.entries(tests)) {
  fn();                                   // warm up
  const t0 = Date.now();
  for (let i = 0; i < runs[name]; i++) fn();
  print(`${name} ${((Date.now() - t0) / runs[name]).toFixed(3)}`);
}
