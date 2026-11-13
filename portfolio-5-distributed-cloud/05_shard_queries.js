// Portfolio 5: what the regional shards hold, and which queries touch which shard.
// docker exec p5_mongos mongosh --quiet /scripts/p5/05_shard_queries.js

const mdb = db.getSiblingDB("marriott");
function title(t) { print("\n=== " + t + " ==="); }
function shardsUsed(query) {
  query().toArray();                       // warm up the cache first, so timings are fair
  const e = query().explain("executionStats");
  const stage = e.executionStats.executionStages;
  const shards = (stage.shards || []).map(s => s.shardName);
  return `${e.queryPlanner.winningPlan.stage}: shards ${shards.join(" + ")}, ` +
         `${e.executionStats.totalDocsExamined} docs examined, ${e.executionStats.executionTimeMillis} ms`;
}

title("1. Where the bookings are stored");
const byShard = {};
["emea", "amer"].forEach(name => {
  const host = db.adminCommand({ listShards: 1 }).shards.find(s => s._id === name).host.split("/")[1];
  const shardDb = new Mongo(`mongodb://${host}/?directConnection=true`).getDB("marriott");
  byShard[name] = shardDb.reservations.aggregate([{ $group: { _id: "$region", n: { $sum: 1 } } }, { $sort: { _id: 1 } }]).toArray();
  const total = byShard[name].reduce((a, r) => a + r.n, 0);
  print(`  shard ${name}: ${total} bookings`);
  byShard[name].forEach(r => print(`      ${r._id.padEnd(26)} ${String(r.n).padStart(6)}`));
});

title("2. Which shard holds a booking at Lagos Marriott Ikeja?");
const lagos = mdb.reservations.findOne({ "hotel.code": "LOSMC", region: "Africa" }, { _id: 1, region: 1, "hotel.name": 1 });
print(`  booking ${lagos._id} (${lagos.hotel.name}, ${lagos.region})`);
print("  " + shardsUsed(() => mdb.reservations.find({ region: "Africa", _id: lagos._id })));

title("3. Query that includes the region: sent to one shard only (targeted)");
print("  arrivals at Lagos hotels on 24 Dec 2026");
print("  " + shardsUsed(() => mdb.reservations.find({ region: "Africa", "hotel.city": "Lagos", check_in: ISODate("2026-12-24") })));

title("4. Same question without the region: every shard has to be asked (scatter-gather)");
print("  " + shardsUsed(() => mdb.reservations.find({ "hotel.city": "Lagos", check_in: ISODate("2026-12-24") })));

title("5. With an index on { region, hotel.city, check_in } on every shard");
mdb.reservations.createIndex({ region: 1, "hotel.city": 1, check_in: 1 });
print("  with the region:    " + shardsUsed(() => mdb.reservations.find({ region: "Africa", "hotel.city": "Lagos", check_in: ISODate("2026-12-24") })));
print("  without the region: " + shardsUsed(() => mdb.reservations.find({ "hotel.city": "Lagos", check_in: ISODate("2026-12-24") })));
mdb.reservations.dropIndex({ region: 1, "hotel.city": 1, check_in: 1 });

title("6. Report across all regions: each shard does its part, mongos merges");
mdb.reservations.aggregate([
  { $group: { _id: "$region", bookings: { $sum: 1 }, nights: { $sum: "$nights" } } },
  { $sort: { bookings: -1 } }
]).forEach(r => print(`  ${r._id.padEnd(26)} ${String(r.bookings).padStart(6)} bookings ${String(r.nights).padStart(7)} nights`));
