// A stand-in for the booking app: saves one booking every 200 ms for SECONDS seconds and
// prints a line for each attempt. Used by failover_test.py.
// Retryable writes are on by default, so the driver retries once after a primary change.
// socketTimeoutMS matters in a network partition: packets to a cut-off server are dropped,
// not refused, so without a timeout the app would wait on a dead connection.

const SECONDS = Number(process.env.SECONDS || 40);
const conn = new Mongo("mongodb://rs1:27017,rs2:27017,rs3:27017/?replicaSet=rs0" +
                       "&serverSelectionTimeoutMS=2000&socketTimeoutMS=3000&w=majority&wtimeoutMS=2000");
const col = conn.getDB("marriott").failover_test;
col.drop();

const end = Date.now() + SECONDS * 1000;
for (let n = 1; Date.now() < end; n++) {
  const t = new Date().toISOString().slice(11, 23);
  try {
    col.insertOne({ _id: n, at: new Date() });
    print(`${t} booking ${String(n).padStart(3)} saved   (primary ${conn.getDB("admin").hello().primary.split(":")[0]})`);
  } catch (e) {
    print(`${t} booking ${String(n).padStart(3)} FAILED  ${e.codeName || e.name}`);
  }
  sleep(200);
}
print(`saved ${col.countDocuments()} bookings`);
