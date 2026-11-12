// Portfolio 5: multi-document transactions on the replica set.
// docker exec p5_rs1 mongosh --quiet /scripts/p5/03_transactions.js
//
// In Portfolio 4 a 3 night stay had to take each night separately and give nights back if
// a later one was full. On a replica set the nights and the booking can be one transaction.

const conn = new Mongo("mongodb://rs1:27017,rs2:27017,rs3:27017/?replicaSet=rs0");
const mdb = conn.getDB("marriott");
const KEYS = ["LOSMC|EXSU|2027-12-24", "LOSMC|EXSU|2027-12-25", "LOSMC|EXSU|2027-12-26"];
const TXN = { readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } };

function title(t) { print("\n=== " + t + " ==="); }
function show() {
  print("  " + mdb.availability.find({ _id: { $in: KEYS } }).sort({ _id: 1 }).toArray()
    .map(d => d._id.slice(-5) + " sold " + d.sold + "/" + d.total).join(", ") +
    " | P5 bookings: " + mdb.reservations.countDocuments({ _id: /^P5TX/ }));
}
function reset(sold) {
  mdb.availability.updateMany({ _id: { $in: KEYS } }, { $set: { sold: sold } });
  mdb.reservations.deleteMany({ _id: /^P5TX/ });
}

// book all nights and save the booking in one transaction
function bookStay(session, conf, guest) {
  const s = session.getDatabase("marriott");
  for (const key of KEYS) {
    const r = s.availability.updateOne({ _id: key, $expr: { $lt: ["$sold", "$total"] } }, { $inc: { sold: 1 } });
    if (r.modifiedCount !== 1) throw new Error("no suite free on " + key.slice(-10));
  }
  s.reservations.insertOne({ _id: conf, guest: { name: guest }, hotel: { code: "LOSMC" },
    room_type: { code: "EXSU" }, check_in: ISODate("2027-12-24"), check_out: ISODate("2027-12-27"),
    nights: 3, nightly_rate: NumberDecimal("573500"), status: "Confirmed" });
}

title("1. Two suites free: the stay is booked in one transaction");
reset(2); show();
let session = conn.startSession();
session.startTransaction(TXN);
bookStay(session, "P5TX1", "Ifeoma Chukwu");
session.commitTransaction();
session.endSession();
print("committed"); show();

title("2. The last night (26 Dec) is full: nothing is changed at all");
reset(2);
mdb.availability.updateOne({ _id: KEYS[2] }, { $set: { sold: 4 } });
show();
session = conn.startSession();
session.startTransaction(TXN);
try {
  bookStay(session, "P5TX2", "Daniel Okoro");
  session.commitTransaction();
} catch (e) {
  session.abortTransaction();
  print("aborted: " + e.message);
}
session.endSession();
print("the 24th and 25th were taken inside the transaction, but the abort undid them:"); show();

title("3. Two guests, one suite left, both in transactions at the same time");
reset(3); show();
const a = conn.startSession(), b = conn.startSession();
a.startTransaction(TXN); b.startTransaction(TXN);
a.getDatabase("marriott").availability.updateOne({ _id: KEYS[0], $expr: { $lt: ["$sold", "$total"] } }, { $inc: { sold: 1 } });
print("A has taken the 24th (not committed yet)");
try {
  b.getDatabase("marriott").availability.updateOne({ _id: KEYS[0], $expr: { $lt: ["$sold", "$total"] } }, { $inc: { sold: 1 } });
  print("B also took it (should not happen)");
} catch (e) {
  print("B tries the same key: " + e.codeName + " (" + (e.errorLabels || []).join(", ") + ")");
  b.abortTransaction();
}
a.abortTransaction();                         // A starts again cleanly and books the whole stay
a.startTransaction(TXN);
bookStay(a, "P5TX3", "Ifeoma Chukwu");
a.commitTransaction();
print("A commits");
b.startTransaction(TXN);
try {
  bookStay(b, "P5TX4", "Daniel Okoro");
  b.commitTransaction();
  print("B retried and booked (should not happen)");
} catch (e) {
  b.abortTransaction();
  print("B retries from the start: " + e.message);
}
a.endSession(); b.endSession();
show();

reset(3);   // leave the demo data as it was
