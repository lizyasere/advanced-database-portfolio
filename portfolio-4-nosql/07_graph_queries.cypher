// Portfolio 4: graph queries in Cypher.
// docker exec marriott_neo4j cypher-shell -u neo4j -p mit8103_pass --format verbose -f /scripts/p4/07_graph_queries.cypher

// 1. Guests who stayed at Lagos Marriott Hotel Ikeja also stayed at...
MATCH (:Hotel {code: 'LOSMC'})<-[:STAYED_AT]-(g:Guest)-[:STAYED_AT]->(other:Hotel)
RETURN other.code AS hotel, other.name AS name, count(DISTINCT g) AS shared_guests
ORDER BY shared_guests DESC LIMIT 5;

// 2. Which cities share the most guests with Lagos? (useful for route marketing)
MATCH (:City {name: 'Lagos'})<-[:LOCATED_IN]-(:Hotel)<-[:STAYED_AT]-(g:Guest)
      -[:STAYED_AT]->(:Hotel)-[:LOCATED_IN]->(c:City)
WHERE c.name <> 'Lagos'
RETURN c.name AS city, count(DISTINCT g) AS shared_guests
ORDER BY shared_guests DESC LIMIT 5;

// 3. Recommend hotels to Layla Chen (guest 63464): places that guests with similar
//    stays went to, which she has not tried yet
MATCH (me:Guest {id: 63464})-[:STAYED_AT]->(h:Hotel)<-[:STAYED_AT]-(similar:Guest)
WITH me, similar, count(h) AS hotels_in_common
ORDER BY hotels_in_common DESC LIMIT 50
MATCH (similar)-[:STAYED_AT]->(rec:Hotel)
WHERE NOT (me)-[:STAYED_AT]->(rec)
RETURN rec.code AS hotel, rec.name AS name, count(*) AS score
ORDER BY score DESC LIMIT 5;

// 4. How are two guests connected? (link analysis, e.g. checking a suspected points-fraud ring)
MATCH p = shortestPath((a:Guest {id: 63464})-[:STAYED_AT*..6]-(b:Guest {id: 89631}))
RETURN [n IN nodes(p) | coalesce(n.name, '') + ' (' + coalesce(n.code, toString(n.id)) + ')'] AS path,
       length(p) AS hops;

// 5. Elite members who have stayed in the most countries (three hops: guest, hotel, city, country)
MATCH (g:Guest)-[:STAYED_AT]->(:Hotel)-[:LOCATED_IN]->(:City)-[:IN_COUNTRY]->(co:Country)
WHERE g.tier IN ['Platinum Elite', 'Titanium Elite', 'Ambassador Elite']
WITH g, count(DISTINCT co) AS countries, collect(DISTINCT co.name)[..5] AS some_countries
RETURN g.id AS guest_id, g.name AS member, g.tier AS tier, countries, some_countries
ORDER BY countries DESC, guest_id LIMIT 5;
