// Portfolio 5: replication and consistency on the 3-node replica set.
// docker exec p5_rs1 mongosh --quiet /scripts/p5/02_replication_consistency.js
//
// Section 4 pauses replication on purpose with a test-only failpoint, to make a stale
// read happen on demand instead of waiting for a slow network.

const RS = "mongodb://rs1:27017,rs2:27017,rs3:27017/?replicaSet=rs0";
const cluster = new Mongo(RS);
const mdb = cluster.getDB("marriott");
const nodes = ["rs1", "rs2", "rs3"];
const direct = n => new Mongo(`mongodb://${n}:27017/?directConnection=true`);
const primaryName = () => rs.status().members.find(m => m.stateStr === "PRIMARY").name.split(":")[0];
const secondaries = () => nodes.filter(n => n !== primaryName());
const CONF = "90654574";   // Layla Chen's booking at Sheraton Lagos, May 2027

function title(t) { print("\n=== " + t + " ==="); }
function statusOn(n) {
  const c = direct(n); c.setReadPref("secondaryPreferred");
  return c.getDB("marriott").reservations.findOne({ _id: CONF }).status;
}
function pauseReplication(n, on) {
  direct(n).getDB("admin").runCommand({ configureFailPoint: "rsSyncApplyStop", mode: on ? "alwaysOn" : "off" });
}

// in case an earlier run stopped half way with replication still paused
nodes.forEach(n => pauseReplication(n, false));

title("1. Every node holds a full copy (full replication)");
print("primary is " + primaryName());
nodes.forEach(n => {
  const c = direct(n); c.setReadPref("secondaryPreferred");
  const d = c.getDB("marriott");
  print(`  ${n}  ${String(d.reservations.countDocuments()).padStart(7)} bookings  ${String(d.guests.countDocuments()).padStart(7)} guests`);
});

title("2. How long a write takes to reach the secondaries (asynchronous replication)");
const lags = [];
const sec = direct(secondaries()[0]); sec.setReadPref("secondaryPreferred");
for (let i = 0; i < 20; i++) {
  const id = "P5LAG" + i;
  mdb.lag_test.insertOne({ _id: id, at: new Date() }, { writeConcern: { w: 1 } });
  const t0 = Date.now();
  while (!sec.getDB("marriott").lag_test.findOne({ _id: id })) sleep(1);
  lags.push(Date.now() - t0);
}
lags.sort((a, b) => a - b);
print(`20 writes: fastest ${lags[0]} ms, median ${lags[10]} ms, slowest ${lags[19]} ms until visible on ${secondaries()[0]}`);
mdb.lag_test.drop();

title("3. Write concern: acknowledged by 1 node or by a majority");
for (const w of [1, "majority"]) {
  const t0 = Date.now();
  for (let i = 0; i < 200; i++) mdb.wc_test.insertOne({ n: i }, { writeConcern: { w: w } });
  print(`  w: ${String(w).padEnd(8)} 200 inserts, ${((Date.now() - t0) / 200).toFixed(2)} ms each`);
}
mdb.wc_test.drop();

title("4. Stale read: replication paused on one secondary");
const [lagging, healthy] = secondaries();
mdb.reservations.updateOne({ _id: CONF }, { $set: { status: "Confirmed" } }, { writeConcern: { w: "majority" } });
pauseReplication(lagging, true);
mdb.reservations.updateOne({ _id: CONF }, { $set: { status: "Cancelled" } }, { writeConcern: { w: 1 } });
print(`guest cancels booking ${CONF} on the primary (${primaryName()})`);
print(`  read from primary   ${primaryName()}: ${statusOn(primaryName())}`);
print(`  read from secondary ${healthy}: ${statusOn(healthy)}`);
print(`  read from secondary ${lagging}: ${statusOn(lagging)}   <- stale`);

title("5. Both secondaries paused: the primary cannot reach a majority");
pauseReplication(healthy, true);
try {
  mdb.reservations.updateOne({ _id: CONF }, { $set: { status: "Confirmed" } },
                             { writeConcern: { w: "majority", wtimeout: 3000 } });
  print("majority write acknowledged (should not happen)");
} catch (e) {
  print("majority write: " + (e.codeName || e.message) + " after 3 s, so the app cannot tell the guest it worked");
}
const t1 = Date.now();
mdb.reservations.updateOne({ _id: CONF }, { $set: { status: "Confirmed" } }, { writeConcern: { w: 1 } });
print(`w: 1 write: acknowledged in ${Date.now() - t1} ms, but only the primary has it`);

title("6. Replication resumes: every node catches up (eventual consistency)");
pauseReplication(lagging, false);
pauseReplication(healthy, false);
const t2 = Date.now();
while (nodes.some(n => statusOn(n) !== "Confirmed")) sleep(10);
print(`all three nodes show "Confirmed" again after ${Date.now() - t2} ms`);
nodes.forEach(n => print(`  ${n}: ${statusOn(n)}`));

title("7. Read your own writes (causally consistent session)");
// The session remembers the time of its last write. A node asked to read "after" that time
// must wait until it has caught up, instead of answering with old data.
pauseReplication(lagging, true);
const session = cluster.startSession({ causalConsistency: true });
session.getDatabase("marriott").reservations.updateOne({ _id: CONF },
  { $set: { special_request: "airport pickup" } }, { writeConcern: { w: "majority" } });
const after = session.getOperationTime();
print("session saves a special request on the primary");
const readAfter = () => {
  const c = direct(lagging); c.setReadPref("secondaryPreferred");
  return c.getDB("marriott").runCommand({ find: "reservations", filter: { _id: CONF },
    readConcern: { level: "local", afterClusterTime: after }, maxTimeMS: 2000 });
};
const plain = direct(lagging); plain.setReadPref("secondaryPreferred");
print(`  read on lagging ${lagging} without the session: special_request = ` +
      plain.getDB("marriott").reservations.findOne({ _id: CONF }).special_request + "   <- stale");
try {
  readAfter();
  print(`  read on lagging ${lagging} with the session: returned (should not happen)`);
} catch (e) {
  print(`  read on lagging ${lagging} with the session: waited 2 s and gave up (${e.codeName || "time limit"}) rather than return old data`);
}
pauseReplication(lagging, false);
const r2 = readAfter();
print(`  after it catches up (with session):    special_request = ${r2.cursor.firstBatch[0].special_request}`);
mdb.reservations.updateOne({ _id: CONF }, { $unset: { special_request: "" } }, { writeConcern: { w: "majority" } });
session.endSession();
