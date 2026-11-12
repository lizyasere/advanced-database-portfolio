-- hotel recommendations for guest 63464, in SQL
\timing on
WITH mine AS (
    SELECT DISTINCT hotel_id FROM crs.reservation WHERE guest_id = 63464 AND res_status = 'Checked Out'
), similar_guests AS (
    SELECT r.guest_id, count(DISTINCT r.hotel_id) AS hotels_in_common
    FROM crs.reservation r JOIN mine USING (hotel_id)
    WHERE r.res_status = 'Checked Out' AND r.guest_id <> 63464
    GROUP BY r.guest_id ORDER BY hotels_in_common DESC LIMIT 50
)
SELECT h.marsha_code, h.hotel_name, count(*) AS score
FROM (SELECT DISTINCT r.guest_id, r.hotel_id
      FROM crs.reservation r JOIN similar_guests s USING (guest_id)
      WHERE r.res_status = 'Checked Out') x
JOIN crs.hotel h USING (hotel_id)
WHERE x.hotel_id NOT IN (SELECT hotel_id FROM mine)
GROUP BY h.marsha_code, h.hotel_name
ORDER BY score DESC LIMIT 5;
