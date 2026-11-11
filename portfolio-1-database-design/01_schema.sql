-- Portfolio 1: Marriott CRS schema (PostgreSQL 16)
-- docker exec marriott_postgres psql -U mit8103 -d marriott_crs -f /scripts/p1/01_schema.sql

DROP SCHEMA IF EXISTS crs CASCADE;
CREATE SCHEMA crs;
SET search_path TO crs;

-- needed for the overlap rule on stay
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- locations and brands

CREATE TABLE country (
    country_code   CHAR(2)      PRIMARY KEY,
    country_name   VARCHAR(80)  NOT NULL UNIQUE,
    region         VARCHAR(40)  NOT NULL
        CHECK (region IN ('Africa', 'Middle East', 'Europe', 'US & Canada',
                          'Asia Pacific', 'Caribbean & Latin America'))
);

CREATE TABLE city (
    city_id        SERIAL       PRIMARY KEY,
    city_name      VARCHAR(80)  NOT NULL,
    country_code   CHAR(2)      NOT NULL REFERENCES country(country_code),
    UNIQUE (city_name, country_code)
);

CREATE TABLE brand (
    brand_id       SERIAL       PRIMARY KEY,
    brand_name     VARCHAR(60)  NOT NULL UNIQUE,
    tier           VARCHAR(20)  NOT NULL
        CHECK (tier IN ('Luxury', 'Premium', 'Select', 'Midscale', 'Extended Stay'))
);

-- hotels, staff and rooms

CREATE TABLE hotel (
    hotel_id       SERIAL       PRIMARY KEY,
    marsha_code    CHAR(5)      NOT NULL UNIQUE
        CHECK (marsha_code ~ '^[A-Z]{5}$'),
    hotel_name     VARCHAR(120) NOT NULL,
    brand_id       INT          NOT NULL REFERENCES brand(brand_id),
    city_id        INT          NOT NULL REFERENCES city(city_id),
    address        VARCHAR(200) NOT NULL,
    star_rating    SMALLINT     NOT NULL CHECK (star_rating BETWEEN 1 AND 5),
    currency_code  CHAR(3)      NOT NULL,
    opened_on      DATE
);

CREATE TABLE staff (
    staff_id       SERIAL       PRIMARY KEY,
    hotel_id       INT          NOT NULL REFERENCES hotel(hotel_id),
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    job_role       VARCHAR(30)  NOT NULL
        CHECK (job_role IN ('Front Desk', 'Reservations', 'Revenue Manager',
                            'General Manager', 'Finance')),
    hired_on       DATE         NOT NULL
);

CREATE TABLE room_type (
    room_type_id   SERIAL       PRIMARY KEY,
    hotel_id       INT          NOT NULL REFERENCES hotel(hotel_id),
    type_code      VARCHAR(10)  NOT NULL,   -- e.g. DLXK
    type_name      VARCHAR(60)  NOT NULL,
    bed_type       VARCHAR(20)  NOT NULL CHECK (bed_type IN ('King', 'Twin', 'Queen', 'Double')),
    max_occupancy  SMALLINT     NOT NULL CHECK (max_occupancy BETWEEN 1 AND 8),
    base_rate      NUMERIC(12,2) NOT NULL CHECK (base_rate > 0),   -- per night
    UNIQUE (hotel_id, type_code),
    UNIQUE (room_type_id, hotel_id)
);

CREATE TABLE room (
    room_id        SERIAL       PRIMARY KEY,
    hotel_id       INT          NOT NULL,
    room_type_id   INT          NOT NULL,
    room_number    VARCHAR(6)   NOT NULL,
    floor_no       SMALLINT     NOT NULL CHECK (floor_no >= 0),
    room_status    VARCHAR(15)  NOT NULL DEFAULT 'Available'
        CHECK (room_status IN ('Available', 'Out of Order', 'Cleaning')),
    UNIQUE (hotel_id, room_number),
    -- room type must be from the same hotel
    FOREIGN KEY (room_type_id, hotel_id) REFERENCES room_type(room_type_id, hotel_id)
);

-- rates

CREATE TABLE rate_plan (
    rate_plan_id        SERIAL      PRIMARY KEY,
    rate_code           VARCHAR(10) NOT NULL UNIQUE,
    rate_name           VARCHAR(60) NOT NULL,
    discount_pct        NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100),
    is_refundable       BOOLEAN     NOT NULL DEFAULT TRUE,
    members_only        BOOLEAN     NOT NULL DEFAULT FALSE
);

-- guests and bonvoy

CREATE TABLE guest (
    guest_id       SERIAL       PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(120) NOT NULL UNIQUE
        CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    phone          VARCHAR(20),
    nationality    CHAR(2)      REFERENCES country(country_code),
    date_of_birth  DATE         CHECK (date_of_birth < CURRENT_DATE),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
    -- no passport number on purpose (see README, Starwood breach)
);

CREATE TABLE bonvoy_account (
    account_id     SERIAL       PRIMARY KEY,
    guest_id       INT          NOT NULL UNIQUE REFERENCES guest(guest_id),
    member_number  CHAR(9)      NOT NULL UNIQUE CHECK (member_number ~ '^[0-9]{9}$'),
    elite_tier     VARCHAR(20)  NOT NULL DEFAULT 'Member'
        CHECK (elite_tier IN ('Member', 'Silver Elite', 'Gold Elite', 'Platinum Elite',
                              'Titanium Elite', 'Ambassador Elite')),
    points_balance INT          NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
    enrolled_on    DATE         NOT NULL DEFAULT CURRENT_DATE
);

-- bookings, stays, payments, points, reviews

CREATE TABLE reservation (
    reservation_id   SERIAL       PRIMARY KEY,
    confirmation_no  VARCHAR(12)  NOT NULL UNIQUE,
    guest_id         INT          NOT NULL REFERENCES guest(guest_id),
    hotel_id         INT          NOT NULL,
    room_type_id     INT          NOT NULL,
    rate_plan_id     INT          NOT NULL REFERENCES rate_plan(rate_plan_id),
    check_in_date    DATE         NOT NULL,
    check_out_date   DATE         NOT NULL,
    num_guests       SMALLINT     NOT NULL CHECK (num_guests BETWEEN 1 AND 8),
    nightly_rate     NUMERIC(12,2) NOT NULL CHECK (nightly_rate >= 0),   -- price at time of booking
    booking_channel  VARCHAR(15)  NOT NULL
        CHECK (booking_channel IN ('Web', 'Mobile App', 'Call Centre', 'Travel Agent', 'Walk-in')),
    res_status       VARCHAR(12)  NOT NULL DEFAULT 'Confirmed'
        CHECK (res_status IN ('Confirmed', 'Checked In', 'Checked Out', 'Cancelled', 'No Show')),
    booked_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK (check_out_date > check_in_date),
    FOREIGN KEY (room_type_id, hotel_id) REFERENCES room_type(room_type_id, hotel_id)
);

-- created at check-in when the guest gets an actual room
CREATE TABLE stay (
    stay_id          SERIAL       PRIMARY KEY,
    reservation_id   INT          NOT NULL UNIQUE REFERENCES reservation(reservation_id),
    room_id          INT          NOT NULL REFERENCES room(room_id),
    checked_in_by    INT          REFERENCES staff(staff_id),
    stay_period      DATERANGE    NOT NULL,
    actual_check_in  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actual_check_out TIMESTAMPTZ,
    CHECK (actual_check_out IS NULL OR actual_check_out > actual_check_in),
    -- no two stays in the same room on overlapping dates
    EXCLUDE USING gist (room_id WITH =, stay_period WITH &&)
);

-- room must be in the same hotel as the booking
CREATE FUNCTION check_stay_room_hotel() RETURNS trigger AS $$
BEGIN
    IF (SELECT hotel_id FROM room WHERE room_id = NEW.room_id)
       <> (SELECT hotel_id FROM reservation WHERE reservation_id = NEW.reservation_id) THEN
        RAISE EXCEPTION 'Room % is not in the hotel of reservation %', NEW.room_id, NEW.reservation_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stay_room_hotel
    BEFORE INSERT OR UPDATE ON stay
    FOR EACH ROW EXECUTE FUNCTION check_stay_room_hotel();

CREATE TABLE payment (
    payment_id       SERIAL       PRIMARY KEY,
    reservation_id   INT          NOT NULL REFERENCES reservation(reservation_id),
    amount           NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency_code    CHAR(3)      NOT NULL,
    pay_method       VARCHAR(15)  NOT NULL
        CHECK (pay_method IN ('Card', 'Bank Transfer', 'Cash', 'Points', 'Corporate')),
    card_last4       CHAR(4)      CHECK (card_last4 ~ '^[0-9]{4}$'),   -- last 4 digits only
    pay_status       VARCHAR(10)  NOT NULL DEFAULT 'Captured'
        CHECK (pay_status IN ('Authorised', 'Captured', 'Refunded', 'Failed')),
    paid_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK (pay_method <> 'Card' OR card_last4 IS NOT NULL)
);

CREATE TABLE points_transaction (
    points_txn_id    SERIAL       PRIMARY KEY,
    account_id       INT          NOT NULL REFERENCES bonvoy_account(account_id),
    reservation_id   INT          REFERENCES reservation(reservation_id),   -- null for bonuses
    txn_type         VARCHAR(10)  NOT NULL
        CHECK (txn_type IN ('Earn', 'Redeem', 'Bonus', 'Expire', 'Adjust')),
    points           INT          NOT NULL CHECK (points <> 0),
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK ((txn_type IN ('Earn', 'Bonus') AND points > 0)
        OR (txn_type IN ('Redeem', 'Expire') AND points < 0)
        OR  txn_type = 'Adjust')
);

CREATE TABLE review (
    review_id        SERIAL       PRIMARY KEY,
    reservation_id   INT          NOT NULL UNIQUE REFERENCES reservation(reservation_id),
    rating           SMALLINT     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text      TEXT,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- indexes on foreign keys (postgres doesn't create these automatically)
CREATE INDEX idx_hotel_city          ON hotel(city_id);
CREATE INDEX idx_room_hotel          ON room(hotel_id);
CREATE INDEX idx_reservation_guest   ON reservation(guest_id);
CREATE INDEX idx_payment_reservation ON payment(reservation_id);
CREATE INDEX idx_points_account      ON points_transaction(account_id);
