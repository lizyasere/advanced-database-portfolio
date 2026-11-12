// Booking against the availability store, used by 05_availability_kv.js and race_availability.py.
// Each key is hotel|room type|night. A night is taken with one atomic update that only
// succeeds while sold < total. If a later night is full, the nights already taken are
// given back (there is no multi-document transaction on a single MongoDB server).

function nightKeys(hotel, roomType, checkIn, nights) {
  const keys = [];
  for (let i = 0; i < nights; i++) {
    const d = new Date(checkIn.getTime() + i * 86400000);
    keys.push(`${hotel}|${roomType}|${d.toISOString().slice(0, 10)}`);
  }
  return keys;
}

function book(hotel, roomType, checkIn, nights) {
  const avail = db.getSiblingDB("marriott").availability;
  const taken = [];
  for (const key of nightKeys(hotel, roomType, checkIn, nights)) {
    const res = avail.updateOne({ _id: key, $expr: { $lt: ["$sold", "$total"] } },
                                { $inc: { sold: 1 } });
    if (res.modifiedCount === 1) {
      taken.push(key);
    } else {
      taken.forEach(k => avail.updateOne({ _id: k }, { $inc: { sold: -1 } }));   // give them back
      return { ok: false, full_night: key, given_back: taken.length };
    }
  }
  return { ok: true, nights: taken.length };
}

// The wrong way, for comparison: read the count, then write. Two guests can both read
// "1 free" before either of them writes.
function bookUnsafe(hotel, roomType, checkIn, nights) {
  const avail = db.getSiblingDB("marriott").availability;
  const keys = nightKeys(hotel, roomType, checkIn, nights);
  const free = avail.find({ _id: { $in: keys } }).toArray().every(d => d.sold < d.total);
  if (!free) return { ok: false };
  sleep(300);   // the time a real app spends between checking and saving
  keys.forEach(k => avail.updateOne({ _id: k }, { $inc: { sold: 1 } }));
  return { ok: true, nights: keys.length };
}
