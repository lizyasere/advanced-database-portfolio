-- Portfolio 4: export the data for the graph as CSV files into graph_import/
-- (that folder is Neo4j's import folder, and is not committed to git).
-- docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p4/export/graph_csv.sql 2>&1"
SET search_path TO crs;

COPY (SELECT h.marsha_code AS code, h.hotel_name AS name, b.brand_name AS brand, b.tier,
             c.city_name AS city, co.country_name AS country, co.region
      FROM hotel h JOIN brand b USING (brand_id) JOIN city c USING (city_id) JOIN country co USING (country_code))
TO '/scripts/p4/graph_import/hotels.csv' WITH (FORMAT csv, HEADER);

COPY (SELECT g.guest_id AS id, g.first_name || ' ' || g.last_name AS name, g.nationality,
             ba.member_number, ba.elite_tier AS tier
      FROM guest g LEFT JOIN bonvoy_account ba ON ba.guest_id = g.guest_id)
TO '/scripts/p4/graph_import/guests.csv' WITH (FORMAT csv, HEADER);

-- one row per guest and hotel: how many completed stays, total nights, last visit
COPY (SELECT r.guest_id, h.marsha_code AS hotel, count(*) AS stays,
             sum(r.check_out_date - r.check_in_date) AS nights, max(r.check_in_date) AS last_stay
      FROM reservation r JOIN hotel h ON h.hotel_id = r.hotel_id
      WHERE r.res_status = 'Checked Out'
      GROUP BY r.guest_id, h.marsha_code)
TO '/scripts/p4/graph_import/stays.csv' WITH (FORMAT csv, HEADER);
