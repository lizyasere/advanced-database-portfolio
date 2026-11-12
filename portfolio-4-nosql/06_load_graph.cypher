// Portfolio 4: load the Marriott graph into Neo4j from the CSV files.
// docker exec marriott_neo4j cypher-shell -u neo4j -p mit8103_pass -f /scripts/p4/06_load_graph.cypher
//
// Nodes:         (:Guest) (:Hotel) (:Brand) (:City) (:Country)
// Relationships: (:Guest)-[:STAYED_AT {stays, nights, last_stay}]->(:Hotel)
//                (:Hotel)-[:PART_OF]->(:Brand)
//                (:Hotel)-[:LOCATED_IN]->(:City)-[:IN_COUNTRY]->(:Country)

MATCH (n) CALL { WITH n DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;

CREATE CONSTRAINT guest_id   IF NOT EXISTS FOR (g:Guest)   REQUIRE g.id IS UNIQUE;
CREATE CONSTRAINT hotel_code IF NOT EXISTS FOR (h:Hotel)   REQUIRE h.code IS UNIQUE;
CREATE CONSTRAINT brand_name IF NOT EXISTS FOR (b:Brand)   REQUIRE b.name IS UNIQUE;
CREATE CONSTRAINT city_name  IF NOT EXISTS FOR (c:City)    REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT country    IF NOT EXISTS FOR (c:Country) REQUIRE c.name IS UNIQUE;

LOAD CSV WITH HEADERS FROM 'file:///hotels.csv' AS row
MERGE (co:Country {name: row.country}) SET co.region = row.region
MERGE (ci:City {name: row.city})
MERGE (ci)-[:IN_COUNTRY]->(co)
MERGE (b:Brand {name: row.brand}) SET b.tier = row.tier
CREATE (h:Hotel {code: row.code, name: row.name})
CREATE (h)-[:PART_OF]->(b)
CREATE (h)-[:LOCATED_IN]->(ci);

LOAD CSV WITH HEADERS FROM 'file:///guests.csv' AS row
CALL {
  WITH row
  CREATE (:Guest {id: toInteger(row.id), name: row.name, nationality: row.nationality,
                  member_number: row.member_number, tier: row.tier})
} IN TRANSACTIONS OF 20000 ROWS;

LOAD CSV WITH HEADERS FROM 'file:///stays.csv' AS row
CALL {
  WITH row
  MATCH (g:Guest {id: toInteger(row.guest_id)})
  MATCH (h:Hotel {code: row.hotel})
  CREATE (g)-[:STAYED_AT {stays: toInteger(row.stays), nights: toInteger(row.nights),
                          last_stay: date(row.last_stay)}]->(h)
} IN TRANSACTIONS OF 20000 ROWS;

MATCH (n) RETURN labels(n)[0] AS node, count(*) AS how_many ORDER BY how_many DESC;
MATCH ()-[r]->() RETURN type(r) AS relationship, count(*) AS how_many ORDER BY how_many DESC;
