// Portfolio 4: check the load. Counts should match the PostgreSQL tables
// (198 hotels, 200,014 guests, 1,000,018 reservations).

db = db.getSiblingDB("marriott");

print("documents:");
["hotels", "guests", "reservations"].forEach(c => {
  const s = db[c].stats();
  print(`  ${c.padEnd(13)} ${String(s.count).padStart(9)} docs, avg ${s.avgObjSize} bytes, ` +
        `${(s.storageSize / 1048576).toFixed(0)} MB on disk (compressed)`);
});

print("\nguests with a Bonvoy account: " + db.guests.countDocuments({ bonvoy: { $exists: true } }));
print("payments embedded in bookings: " +
      db.reservations.aggregate([{ $group: { _id: null, n: { $sum: { $size: { $ifNull: ["$payments", []] } } } } }]).next().n);
