// Portfolio 5: start the 3-node replica set and wait for a primary.
// docker exec p5_rs1 mongosh --quiet /scripts/p5/01_init_replica_set.js

try {
  rs.initiate({ _id: "rs0", members: [
    { _id: 0, host: "rs1:27017" },
    { _id: 1, host: "rs2:27017" },
    { _id: 2, host: "rs3:27017" } ] });
} catch (e) {
  if (!String(e).includes("already initialized")) throw e;
}

let primary;
for (let i = 0; i < 60 && !primary; i++) {
  sleep(1000);
  primary = rs.status().members.find(m => m.stateStr === "PRIMARY");
}
rs.status().members.forEach(m => print(`${m.name.padEnd(10)} ${m.stateStr}`));
