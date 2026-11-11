-- =====================================================================
-- MIT 8103 Portfolio 1: Sample data
-- Hotel names and addresses are real Marriott properties. MARSHA codes
-- LOSFP and LOSSI are the real codes; the other codes, and all guests,
-- bookings, payments and prices, are made up for this exercise.
--
-- Run:  docker exec -i marriott_postgres psql -U mit8103 -d marriott_crs -f /scripts/p1/02_seed_data.sql
-- =====================================================================
SET search_path TO crs;

INSERT INTO country (country_code, country_name, region) VALUES
 ('NG', 'Nigeria',              'Africa'),
 ('GH', 'Ghana',                'Africa'),
 ('AE', 'United Arab Emirates', 'Middle East'),
 ('GB', 'United Kingdom',       'Europe'),
 ('US', 'United States',        'US & Canada'),
 ('ZA', 'South Africa',         'Africa');

INSERT INTO city (city_name, country_code) VALUES
 ('Lagos', 'NG'), ('Abuja', 'NG'), ('Accra', 'GH'),
 ('Dubai', 'AE'), ('London', 'GB'), ('New York', 'US');

INSERT INTO brand (brand_name, tier) VALUES
 ('The Ritz-Carlton',  'Luxury'),
 ('JW Marriott',       'Luxury'),
 ('Marriott Hotels',   'Premium'),
 ('Sheraton',          'Premium'),
 ('Westin',            'Premium'),
 ('Four Points',       'Select'),
 ('Courtyard',         'Select'),
 ('Residence Inn',     'Extended Stay');

INSERT INTO hotel (marsha_code, hotel_name, brand_id, city_id, address, star_rating, currency_code, opened_on)
SELECT v.code, v.name, b.brand_id, c.city_id, v.address, v.stars, v.cur, v.opened::date
FROM (VALUES
 ('LOSMC', 'Lagos Marriott Hotel Ikeja',          'Marriott Hotels', 'Lagos',    '122 Joel Ogunnaike Street, Ikeja GRA',              5, 'NGN', '2021-03-01'),
 ('LOSSI', 'Sheraton Lagos Hotel',                'Sheraton',        'Lagos',    '30 Mobolaji Bank Anthony Way, Ikeja',               5, 'NGN', '1985-06-01'),
 ('LOSFP', 'Four Points by Sheraton Lagos',       'Four Points',     'Lagos',    'Plot 9/10 Block 2, Oniru Estate, Victoria Island',  4, 'NGN', '2014-04-01'),
 ('ABVSI', 'Sheraton Abuja Hotel',                'Sheraton',        'Abuja',    '1 Ladi Kwali Street, Maitama',                      5, 'NGN', '1986-01-01'),
 ('ACCMC', 'Accra Marriott Hotel',                'Marriott Hotels', 'Accra',    'Liberation Road, Airport City',                     5, 'GHS', '2016-03-01'),
 ('DXBJW', 'JW Marriott Marquis Hotel Dubai',     'JW Marriott',     'Dubai',    'Sheikh Zayed Road, Business Bay',                   5, 'AED', '2012-11-01'),
 ('LONWH', 'London Marriott Hotel County Hall',   'Marriott Hotels', 'London',   'Westminster Bridge Road',                           5, 'GBP', '1993-01-01'),
 ('NYCMQ', 'New York Marriott Marquis',           'Marriott Hotels', 'New York', '1535 Broadway, Times Square',                       4, 'USD', '1985-09-01')
) AS v(code, name, brand, city, address, stars, cur, opened)
JOIN brand b ON b.brand_name = v.brand
JOIN city  c ON c.city_name  = v.city;

-- Three room types per hotel. Prices are per night in the hotel's own currency.
INSERT INTO room_type (hotel_id, type_code, type_name, bed_type, max_occupancy, base_rate)
SELECT h.hotel_id, t.code, t.name, t.bed, t.occ, round(p.deluxe * t.factor, 2)
FROM hotel h
JOIN (VALUES ('LOSMC', 310000), ('LOSSI', 240000), ('LOSFP', 195000), ('ABVSI', 230000),
             ('ACCMC', 3600),   ('DXBJW', 950),    ('LONWH', 420),    ('NYCMQ', 389))
     AS p(code, deluxe) ON p.code = h.marsha_code
CROSS JOIN (VALUES ('DLXK', 'Deluxe King',     'King', 2, 1.00),
                   ('DLXT', 'Deluxe Twin',     'Twin', 3, 1.00),
                   ('EXSU', 'Executive Suite', 'King', 4, 1.85))
     AS t(code, name, bed, occ, factor);

-- 20 rooms per hotel: floors 1 to 4, rooms x01 to x05.
-- x01 and x02 are Deluxe King, x03 and x04 are Deluxe Twin, x05 is the suite.
INSERT INTO room (hotel_id, room_type_id, room_number, floor_no)
SELECT h.hotel_id, rt.room_type_id, (f * 100 + n)::text, f
FROM hotel h
CROSS JOIN generate_series(1, 4) AS f
CROSS JOIN generate_series(1, 5) AS n
JOIN room_type rt ON rt.hotel_id = h.hotel_id
                 AND rt.type_code = CASE WHEN n <= 2 THEN 'DLXK' WHEN n <= 4 THEN 'DLXT' ELSE 'EXSU' END;

INSERT INTO rate_plan (rate_code, rate_name, discount_pct, is_refundable, members_only) VALUES
 ('FLEX',   'Flexible Rate',          0,   TRUE,  FALSE),
 ('MEMBER', 'Bonvoy Member Rate',     5,   TRUE,  TRUE),
 ('ADVPUR', 'Advance Purchase',       15,  FALSE, FALSE),
 ('CORP',   'Corporate Negotiated',   12,  TRUE,  FALSE),
 ('POINTS', 'Bonvoy Points Award',    100, FALSE, TRUE);

INSERT INTO staff (hotel_id, first_name, last_name, job_role, hired_on)
SELECT h.hotel_id, v.fn, v.ln, v.role, v.hired::date
FROM (VALUES
 ('LOSMC', 'Tunde',    'Bakare',   'Front Desk',      '2021-02-15'),
 ('LOSMC', 'Ngozi',    'Eze',      'General Manager', '2020-11-01'),
 ('LOSSI', 'Ibrahim',  'Musa',     'Front Desk',      '2019-05-20'),
 ('LOSFP', 'Chiamaka', 'Obi',      'Front Desk',      '2022-08-01'),
 ('ABVSI', 'Halima',   'Abubakar', 'Front Desk',      '2018-03-12'),
 ('ABVSI', 'Emeka',    'Nwosu',    'Revenue Manager', '2017-09-04'),
 ('DXBJW', 'Aisha',    'Rahman',   'Front Desk',      '2020-01-10'),
 ('NYCMQ', 'Daniel',   'Brooks',   'Front Desk',      '2016-06-30')
) AS v(code, fn, ln, role, hired)
JOIN hotel h ON h.marsha_code = v.code;

INSERT INTO guest (first_name, last_name, email, phone, nationality, date_of_birth) VALUES
 ('Adaeze',   'Okafor',    'adaeze.okafor@example.com',    '+2348031112233', 'NG', '1988-04-12'),
 ('Oluwaseun','Adeyemi',   'seun.adeyemi@example.com',     '+2348024455667', 'NG', '1979-11-03'),
 ('Fatima',   'Bello',     'fatima.bello@example.com',     '+2348097788990', 'NG', '1992-07-25'),
 ('Kwame',    'Mensah',    'kwame.mensah@example.com',     '+233244123456',  'GH', '1985-01-30'),
 ('Chinedu',  'Okonkwo',   'chinedu.okonkwo@example.com',  '+2348135566778', 'NG', '1990-09-14'),
 ('Sarah',    'Thompson',  'sarah.thompson@example.com',   '+447700900123',  'GB', '1983-02-08'),
 ('James',    'Carter',    'james.carter@example.com',     '+12125550147',   'US', '1975-12-19'),
 ('Amara',    'Nnamdi',    'amara.nnamdi@example.com',     '+2349062233445', 'NG', '1996-05-02'),
 ('Yusuf',    'Al-Hashimi','yusuf.alhashimi@example.com',  '+971501234567',  'AE', '1981-08-21'),
 ('Thandiwe', 'Dlamini',   'thandiwe.dlamini@example.com', '+27821234567',   'ZA', '1993-03-17'),
 ('Bola',     'Ogunleye',  'bola.ogunleye@example.com',    '+2348026677889', 'NG', '1987-10-09'),
 ('Grace',    'Etim',      'grace.etim@example.com',       '+2348051122334', 'NG', '1999-06-28');

INSERT INTO bonvoy_account (guest_id, member_number, elite_tier, points_balance, enrolled_on)
SELECT g.guest_id, v.num, v.tier, v.pts, v.enrolled::date
FROM (VALUES
 ('adaeze.okafor@example.com',    '104338271', 'Gold Elite',       48200, '2019-03-02'),
 ('seun.adeyemi@example.com',     '102994105', 'Titanium Elite',  312450, '2014-07-19'),
 ('fatima.bello@example.com',     '118230067', 'Member',            3100, '2024-01-11'),
 ('kwame.mensah@example.com',     '109775432', 'Platinum Elite',  156000, '2016-05-23'),
 ('chinedu.okonkwo@example.com',  '115620984', 'Silver Elite',     21750, '2021-09-30'),
 ('sarah.thompson@example.com',   '101882346', 'Platinum Elite',   98400, '2012-02-14'),
 ('james.carter@example.com',     '100453219', 'Ambassador Elite',640000, '2009-10-01'),
 ('yusuf.alhashimi@example.com',  '107736510', 'Gold Elite',       67300, '2017-12-05'),
 ('bola.ogunleye@example.com',    '119004421', 'Member',               0, '2026-08-20')
) AS v(email, num, tier, pts, enrolled)
JOIN guest g ON g.email = v.email;

-- Reservations. The nightly rate is worked out from the room type's base rate
-- and the rate plan discount, which is how the price is fixed at booking time.
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate,
                         booking_channel, res_status, booked_at)
SELECT v.conf, g.guest_id, h.hotel_id, rt.room_type_id, rp.rate_plan_id,
       v.cin::date, v.cout::date, v.pax,
       round(rt.base_rate * (1 - rp.discount_pct / 100), 2),
       v.channel, v.status, v.booked::timestamptz
FROM (VALUES
 ('84213097', 'adaeze.okafor@example.com',    'LOSMC', 'DLXK', 'MEMBER', '2026-10-02', '2026-10-05', 2, 'Mobile App',   'Checked Out', '2026-09-10 09:14+01'),
 ('84213354', 'seun.adeyemi@example.com',     'ABVSI', 'EXSU', 'CORP',   '2026-10-12', '2026-10-15', 1, 'Web',          'Checked Out', '2026-09-28 18:40+01'),
 ('84214410', 'fatima.bello@example.com',     'LOSFP', 'DLXT', 'ADVPUR', '2026-10-20', '2026-10-22', 2, 'Web',          'Checked Out', '2026-08-30 12:05+01'),
 ('84215902', 'kwame.mensah@example.com',     'ACCMC', 'DLXK', 'MEMBER', '2026-11-08', '2026-11-12', 1, 'Mobile App',   'Checked In',  '2026-10-21 07:55+00'),
 ('84216033', 'chinedu.okonkwo@example.com',  'LOSSI', 'DLXK', 'FLEX',   '2026-11-09', '2026-11-13', 2, 'Call Centre',  'Checked In',  '2026-11-01 15:22+01'),
 ('84216588', 'sarah.thompson@example.com',   'LONWH', 'DLXK', 'MEMBER', '2026-11-10', '2026-11-14', 2, 'Web',          'Checked In',  '2026-10-15 20:11+00'),
 ('84217120', 'james.carter@example.com',     'NYCMQ', 'EXSU', 'POINTS', '2026-11-20', '2026-11-23', 2, 'Mobile App',   'Confirmed',   '2026-10-05 11:30-05'),
 ('84217455', 'amara.nnamdi@example.com',     'LOSMC', 'DLXT', 'FLEX',   '2026-11-21', '2026-11-24', 3, 'Travel Agent', 'Confirmed',   '2026-11-03 10:02+01'),
 ('84217809', 'yusuf.alhashimi@example.com',  'DXBJW', 'EXSU', 'MEMBER', '2026-12-01', '2026-12-04', 2, 'Web',          'Confirmed',   '2026-11-02 13:45+04'),
 ('84218011', 'thandiwe.dlamini@example.com', 'ABVSI', 'DLXK', 'ADVPUR', '2026-12-05', '2026-12-08', 1, 'Web',          'Confirmed',   '2026-10-28 16:20+02'),
 ('84218376', 'bola.ogunleye@example.com',    'LOSFP', 'DLXK', 'MEMBER', '2026-12-18', '2026-12-22', 2, 'Mobile App',   'Confirmed',   '2026-11-06 08:47+01'),
 ('84218590', 'grace.etim@example.com',       'LOSSI', 'DLXT', 'FLEX',   '2026-10-25', '2026-10-27', 2, 'Walk-in',      'Cancelled',   '2026-10-24 19:03+01'),
 ('84218722', 'seun.adeyemi@example.com',     'LOSMC', 'EXSU', 'CORP',   '2026-12-10', '2026-12-12', 1, 'Call Centre',  'Confirmed',   '2026-11-09 09:30+01'),
 ('84218905', 'adaeze.okafor@example.com',    'DXBJW', 'DLXK', 'MEMBER', '2026-10-28', '2026-10-30', 2, 'Mobile App',   'No Show',     '2026-10-01 22:18+01')
) AS v(conf, email, code, type_code, rate_code, cin, cout, pax, channel, status, booked)
JOIN guest g      ON g.email = v.email
JOIN hotel h      ON h.marsha_code = v.code
JOIN room_type rt ON rt.hotel_id = h.hotel_id AND rt.type_code = v.type_code
JOIN rate_plan rp ON rp.rate_code = v.rate_code;

-- Stays for guests who have checked in (or already checked out)
INSERT INTO stay (reservation_id, room_id, checked_in_by, stay_period, actual_check_in, actual_check_out)
SELECT r.reservation_id, rm.room_id, s.staff_id,
       daterange(r.check_in_date, r.check_out_date),
       v.cin::timestamptz, v.cout::timestamptz
FROM (VALUES
 ('84213097', '201', 'Tunde',   '2026-10-02 14:20+01', '2026-10-05 11:05+01'),
 ('84213354', '305', 'Halima',  '2026-10-12 15:02+01', '2026-10-15 10:40+01'),
 ('84214410', '103', 'Chiamaka','2026-10-20 13:55+01', '2026-10-22 11:58+01'),
 ('84215902', '102', NULL,      '2026-11-08 16:10+00', NULL),
 ('84216033', '401', 'Ibrahim', '2026-11-09 14:45+01', NULL),
 ('84216588', '302', NULL,      '2026-11-10 15:30+00', NULL)
) AS v(conf, room_no, staff_name, cin, cout)
JOIN reservation r ON r.confirmation_no = v.conf
JOIN room rm       ON rm.hotel_id = r.hotel_id AND rm.room_number = v.room_no
LEFT JOIN staff s  ON s.hotel_id = r.hotel_id AND s.first_name = v.staff_name;

-- Payments: total = nightly rate x number of nights, in the hotel's currency
INSERT INTO payment (reservation_id, amount, currency_code, pay_method, card_last4, pay_status, paid_at)
SELECT r.reservation_id,
       r.nightly_rate * (r.check_out_date - r.check_in_date),
       h.currency_code, v.method, v.last4, v.status, v.paid::timestamptz
FROM (VALUES
 ('84213097', 'Card',          '4417', 'Captured', '2026-10-05 11:00+01'),
 ('84213354', 'Corporate',     NULL,   'Captured', '2026-10-15 10:35+01'),
 ('84214410', 'Bank Transfer', NULL,   'Captured', '2026-08-30 12:10+01'),
 ('84215902', 'Card',          '9021', 'Authorised','2026-11-08 16:12+00'),
 ('84216033', 'Card',          '5530', 'Authorised','2026-11-09 14:47+01'),
 ('84216588', 'Card',          '1184', 'Authorised','2026-11-10 15:31+00'),
 ('84218011', 'Card',          '7302', 'Captured', '2026-10-28 16:22+02')
) AS v(conf, method, last4, status, paid)
JOIN reservation r ON r.confirmation_no = v.conf
JOIN hotel h       ON h.hotel_id = r.hotel_id;

-- Bonvoy points activity
INSERT INTO points_transaction (account_id, reservation_id, txn_type, points, created_at)
SELECT a.account_id, r.reservation_id, v.txn_type, v.pts, v.at::timestamptz
FROM (VALUES
 ('104338271', '84213097', 'Earn',   6200,   '2026-10-06 02:00+01'),
 ('102994105', '84213354', 'Earn',   15400,  '2026-10-16 02:00+01'),
 ('118230067', '84214410', 'Earn',   3100,   '2026-10-23 02:00+01'),
 ('100453219', '84217120', 'Redeem', -150000,'2026-10-05 11:31-05'),
 ('104338271', NULL,       'Bonus',  2000,   '2026-09-01 00:00+01')
) AS v(member_no, conf, txn_type, pts, at)
JOIN bonvoy_account a ON a.member_number = v.member_no
LEFT JOIN reservation r ON r.confirmation_no = v.conf;

INSERT INTO review (reservation_id, rating, review_text, created_at)
SELECT r.reservation_id, v.rating, v.txt, v.at::timestamptz
FROM (VALUES
 ('84213097', 5, 'Very quiet room and the breakfast was excellent. Check-in was quick.', '2026-10-06 18:00+01'),
 ('84213354', 4, 'Good suite and helpful staff, but the Wi-Fi dropped a few times.',     '2026-10-16 09:12+01'),
 ('84214410', 3, 'Nice location in Victoria Island. Air conditioning was noisy at night.', '2026-10-23 12:40+01')
) AS v(conf, rating, txt, at)
JOIN reservation r ON r.confirmation_no = v.conf;
