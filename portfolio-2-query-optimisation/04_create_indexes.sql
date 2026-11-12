-- Portfolio 2: indexes chosen from the baseline plans
-- docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p2/04_create_indexes.sql 2>&1"

SET search_path TO crs;
\timing on

-- Q1 availability. Partial index: only bookings that still hold a room
-- (Confirmed / Checked In) are indexed, so cancelled and past stays are left out.
CREATE INDEX IF NOT EXISTS idx_res_roomtype_active
    ON reservation (room_type_id, check_in_date)
    INCLUDE (check_out_date)
    WHERE res_status IN ('Confirmed', 'Checked In');

-- Q2 email lookup. Expression index on lower(email).
-- UNIQUE also stops Ada@x.com and ada@x.com being registered as two guests.
CREATE UNIQUE INDEX IF NOT EXISTS idx_guest_email_lower
    ON guest (lower(email));

-- Q3b and Q4: one hotel, a date or date range.
-- INCLUDE adds the columns Q3b needs so it can be answered from the index alone.
CREATE INDEX IF NOT EXISTS idx_res_hotel_checkin
    ON reservation (hotel_id, check_in_date)
    INCLUDE (check_out_date, nightly_rate, res_status);

-- Q5b: earned points by date. Covering index so the table itself isn't read.
CREATE INDEX IF NOT EXISTS idx_points_earn_date
    ON points_transaction (created_at)
    INCLUDE (account_id, points)
    WHERE txn_type = 'Earn';

ANALYZE reservation;
ANALYZE guest;
ANALYZE points_transaction;

\echo '=== Index sizes compared with their tables ==='
SELECT c.relname AS index_name, t.relname AS table_name,
       pg_size_pretty(pg_relation_size(c.oid)) AS index_size,
       pg_size_pretty(pg_relation_size(t.oid)) AS table_size
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_class t ON t.oid = i.indrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'crs' AND t.relname IN ('reservation', 'guest', 'points_transaction')
ORDER BY t.relname, pg_relation_size(c.oid) DESC;
