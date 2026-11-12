-- Portfolio 2: removes the Portfolio 2 indexes so the "before" state can be measured again
-- docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p2/05_drop_indexes.sql 2>&1"

SET search_path TO crs;
DROP INDEX IF EXISTS idx_res_roomtype_active;
DROP INDEX IF EXISTS idx_guest_email_lower;
DROP INDEX IF EXISTS idx_res_hotel_checkin;
DROP INDEX IF EXISTS idx_points_earn_date;
ANALYZE reservation;
ANALYZE guest;
ANALYZE points_transaction;
