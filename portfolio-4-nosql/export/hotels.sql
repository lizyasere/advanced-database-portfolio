-- One document per hotel, with its room types embedded.
-- The "features" object has a different shape for each brand (sample values, to show
-- that documents in one collection do not need the same fields).
SET search_path TO crs;

SELECT json_build_object(
    '_id', h.marsha_code,
    'name', h.hotel_name,
    'brand', json_build_object('name', b.brand_name, 'tier', b.tier),
    'location', json_build_object('address', h.address, 'city', c.city_name,
                                   'country', co.country_name, 'region', co.region),
    'star_rating', h.star_rating,
    'currency', h.currency_code,
    'opened_on', json_build_object('$date', to_char(h.opened_on, 'YYYY-MM-DD"T00:00:00Z"')),
    'room_types', (SELECT json_agg(json_build_object(
                        'code', rt.type_code,
                        'name', rt.type_name,
                        'bed', rt.bed_type,
                        'max_occupancy', rt.max_occupancy,
                        'base_rate', json_build_object('$numberDecimal', rt.base_rate::text),
                        'rooms', (SELECT count(*) FROM room r WHERE r.room_type_id = rt.room_type_id))
                      ORDER BY rt.base_rate)
                   FROM room_type rt WHERE rt.hotel_id = h.hotel_id),
    'features', (CASE b.tier
        WHEN 'Luxury'        THEN jsonb_build_object('spa', true, 'club_lounge', true,
                                                     'butler_service', b.brand_name = 'The Ritz-Carlton')
        WHEN 'Premium'       THEN jsonb_build_object('club_lounge', true, 'meeting_rooms', 4 + h.hotel_id % 9)
        WHEN 'Select'        THEN jsonb_build_object('grab_and_go_market', true)
        WHEN 'Extended Stay' THEN jsonb_build_object('kitchen_in_room', true, 'weekly_rates', true,
                                                     'pet_friendly', h.hotel_id % 2 = 0)
    END
    || CASE WHEN co.country_name = 'Nigeria'
            THEN jsonb_build_object('backup_power', '24 hour generator and inverter', 'airport_shuttle', true)
            ELSE '{}'::jsonb END)::json
)::text
FROM hotel h
JOIN brand b USING (brand_id)
JOIN city c USING (city_id)
JOIN country co USING (country_code)
ORDER BY h.hotel_id;
