// Portfolio 5: the same booking operations timed on the local replica set and on MongoDB Atlas.
// Run by cloud_latency.py, which passes the connection string to mongosh.
// Each operation runs 30 times after a warm-up; median and 95th percentile in ms.

const RUNS = 30;
const mdb = db.getSiblingDB("marriott");
const KEYS = ["LOSMC|EXSU|2027-12-24", "LOSMC|EXSU|2027-12-25", "LOSMC|EXSU|2027-12-26"];
const tags = db.hello().tags || {};
// a full booking, so the schema validator does the same work as for a real one
const booking = id => ({ _id: id, guest: { id: 0, name: "Latency Test" }, hotel: { code: "LOSMC" },
  room_type: { code: "EXSU" }, check_in: ISODate("2027-12-24"), check_out: ISODate("2027-12-27"),
  nights: 3, nightly_rate: NumberDecimal("573500"), status: "Confirmed" });
const where = tags.provider ? `Atlas M0, ${tags.provider} ${tags.region}` : "local Docker replica set rs0";

function timeIt(label, fn) {
  fn();                                            // warm-up, not counted
  const t = [];
  for (let i = 0; i < RUNS; i++) {
    const s = Date.now();
    fn(i);
    t.push(Date.now() - s);
  }
  t.sort((a, b) => a - b);
  const median = t[Math.floor(RUNS / 2)], p95 = t[Math.ceil(RUNS * 0.95) - 1];
  print(`  ${label.padEnd(44)} ${String(median).padStart(5)} ${String(p95).padStart(6)}`);
}

// the same guest and hotel on both sides
const sample = mdb.reservations.find({ "hotel.code": "LOSMC" }).sort({ _id: 1 }).limit(1).next();
const guest = mdb.guests.findOne({ _id: sample.guest.id }, { email: 1 });
const day = sample.check_in;

print(`Target: ${where}, MongoDB ${db.version()}`);
print(`Sample: guest ${sample.guest.id}, LOSMC arrivals on ${day.toISOString().slice(0, 10)}`);
print(`  ${"operation".padEnd(44)} ${"median".padStart(5)} ${"p95".padStart(6)}`);

timeIt("ping (network round trip only)", () => db.runCommand({ ping: 1 }));
timeIt("guest profile by email", () => mdb.guests.findOne({ email: guest.email }));
timeIt("guest's bookings, newest first", () => mdb.reservations.find({ "guest.id": sample.guest.id }).sort({ check_in: -1 }).toArray());
timeIt("arrivals at Lagos Marriott Ikeja on one day", () => mdb.reservations.find({ "hotel.code": "LOSMC", check_in: day }).toArray());
timeIt("insert booking, w:1", i => mdb.reservations.insertOne(booking("P5LAT1-" + i), { writeConcern: { w: 1 } }));
timeIt("insert booking, w:majority", i => mdb.reservations.insertOne(booking("P5LAT2-" + i), { writeConcern: { w: "majority" } }));

// 3-night stay as one transaction (as in 03_transactions.js), undone after each run
const before = mdb.availability.find({ _id: { $in: KEYS } }).toArray();
timeIt("3-night booking in one transaction", i => {
  const session = db.getMongo().startSession();
  session.startTransaction({ readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } });
  const s = session.getDatabase("marriott");
  KEYS.forEach(k => s.availability.updateOne({ _id: k }, { $inc: { sold: 1 } }));
  s.reservations.insertOne(booking("P5LAT3-" + (i === undefined ? "w" : i)));
  session.commitTransaction();
  session.endSession();
  mdb.availability.updateMany({ _id: { $in: KEYS } }, { $inc: { sold: -1 } });
});
timeIt("report: bookings and nights per region", () => mdb.reservations.aggregate([
  { $group: { _id: "$region", bookings: { $sum: 1 }, nights: { $sum: "$nights" } } }]).toArray());

// how much of the arrivals query is the server and how much is the network
const e = mdb.reservations.find({ "hotel.code": "LOSMC", check_in: day }).explain("executionStats");
print(`Arrivals query time on the server itself: ${e.executionStats.executionTimeMillis} ms ` +
      `(${e.executionStats.nReturned} bookings, ${e.executionStats.totalDocsExamined} examined)`);

mdb.reservations.deleteMany({ _id: /^P5LAT/ });
const after = mdb.availability.find({ _id: { $in: KEYS } }).toArray();
print(`Clean-up: test bookings removed, availability unchanged: ${JSON.stringify(before) === JSON.stringify(after)}`);
