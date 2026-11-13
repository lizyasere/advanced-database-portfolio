// Portfolio 5: shard the bookings by region (horizontal fragmentation), run on the mongos router.
// Called by shard_setup.py.
//
// Two shards, each one standing for a group of data centres:
//   emea  Africa, Europe, Middle East
//   amer  US & Canada, Caribbean & Latin America, Asia Pacific
// A zone pins every booking to the shard for its hotel's region, so a Lagos booking is
// stored in EMEA and never leaves it unless a query asks for it.

const ZONES = {
  EMEA: ["Africa", "Europe", "Middle East"],
  AMER_APAC: ["Asia Pacific", "Caribbean & Latin America", "US & Canada"]
};

["emea/shard_emea:27017", "amer/shard_amer:27017"].forEach(s => {
  if (!db.adminCommand({ listShards: 1 }).shards.some(x => x.host === s)) sh.addShard(s);
});
sh.addShardToZone("emea", "EMEA");
sh.addShardToZone("amer", "AMER_APAC");

const mdb = db.getSiblingDB("marriott");
mdb.reservations.drop();
sh.enableSharding("marriott", "emea");
for (const [zone, regions] of Object.entries(ZONES)) {
  for (const r of regions) {
    sh.updateZoneKeyRange("marriott.reservations", { region: r, _id: MinKey }, { region: r, _id: MaxKey }, zone);
  }
}
sh.shardCollection("marriott.reservations", { region: 1, _id: 1 });

print("shards: " + db.adminCommand({ listShards: 1 }).shards.map(s => s._id + " (" + s.tags.join(",") + ")").join(", "));
print("bookings are sharded on { region, _id } with " +
      Object.values(ZONES).flat().length + " region ranges in 2 zones");
