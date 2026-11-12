Average time per query (baseline: 500 runs, profile: 500 runs, booking: 500 runs, brand_nights: 5 runs)

| Screen | PostgreSQL (ms) | PostgreSQL + index on points.reservation_id (ms) | MongoDB (ms) |
|---|---|---|---|
| Empty query (SELECT 1 / ping): client and round trip only | 0.215 | 0.110 | 1.900 |
| Guest profile screen (profile, Bonvoy, 3 recent bookings) | 0.867 | 0.832 | 2.766 |
| Booking detail screen (booking, guest, hotel, room, payments, points) | 21.818 | 0.842 | 2.496 |
| Room nights by brand, last 12 months (analytics) | 47.277 | 47.225 | 621.600 |
