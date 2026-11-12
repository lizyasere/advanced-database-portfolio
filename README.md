# Advanced Database Systems Portfolio (MIT 8103)

**Student:** Elizabeth Iyasere  
**Matriculation No.:** 2026/A/MIT/0842  
**Programme:** Master of Information Technology, MIVA Open University (2026/2027, First Semester)

## Case Study: Marriott International

For this portfolio I chose Marriott International, the largest hotel company in the world. At the
end of 2025 Marriott had more than 9,800 hotels and about 1.78 million rooms in 145 countries and
territories. It runs over 30 brands, including JW Marriott, Ritz-Carlton, Sheraton, Westin, Four
Points and Courtyard, and its loyalty programme, Marriott Bonvoy, has close to 271 million members.
Here in Nigeria, Marriott operates the Lagos Marriott Hotel Ikeja, Sheraton Lagos, Four Points by
Sheraton Lagos and Sheraton Abuja.

I am building a simplified version of the database behind Marriott's central reservation system
and the Bonvoy loyalty programme. Marriott's real data is not public, so the records are made up,
but the tables and business rules follow the way a global hotel group actually works.

I picked Marriott because its own technology story lines up well with the topics in this course:

| What happened at Marriott | Where I use it |
|---|---|
| Its old reservation system, MARSHA, ran on one mainframe. Parts of it were later moved to a NoSQL database (Couchbase) because guests expected faster answers online. | Portfolio 4 |
| Since 2025 it has been moving to a new cloud based reservation system built with Amadeus. | Portfolio 5 |
| Hackers sat inside the Starwood reservation database from 2014 until 2018 and exposed about 339 million guest records. The UK regulator fined Marriott £18.4 million in 2020. | Portfolio 1 and my reflection |
| Hotels in 145 countries all sell rooms from the same inventory at the same time. | Portfolios 3 and 5 |

### Summary of the case study

| Item | Details |
|---|---|
| Type of business | Global hotel operator and franchisor, with a central booking system |
| Who uses the database | Guests booking online or on the app, front desk staff, hotel general managers, revenue managers, the Bonvoy loyalty team, finance, and head office analysts |
| Main data stored | Brands, hotels, room types, rooms, rate plans, guests, Bonvoy accounts, reservations, stays, payments, points transactions and reviews |
| Main operations | Search for available rooms, make, change or cancel a booking, stop the same room being sold twice, check guests in and out, take payments, earn and redeem points, and report on occupancy and revenue |

## How the repository is organised

| Folder | What it contains | Status |
|---|---|---|
| `portfolio-1-database-design/` | ER diagram, relational schema, keys, constraints and normalisation | Complete |
| `portfolio-2-query-optimisation/` | SQL queries, execution plans, indexing and performance results | Complete |
| `portfolio-3-transactions-concurrency/` | Commit and rollback, isolation levels, stopping double bookings | Complete |
| `portfolio-4-nosql/` | MongoDB model of the same Marriott data | Not started |
| `portfolio-5-distributed-cloud/` | Replication, sharding and consistency, with a working setup | Not started |
| `docs/` | Final documentation submitted on the LMS | Not started |
| `screenshots/` | Screenshots used as evidence across all portfolios | |

## Setup

Everything runs in Docker, so anyone can rebuild the same environment on their own machine.

| Tool | Version |
|---|---|
| PostgreSQL | 16.4 (image `postgres:16.4`, on host port 5433) |
| MongoDB | 7.0.14 (image `mongo:7.0.14`, on host port 27017) |
| Docker Engine and Compose | 29.6.1 and v5.1.4 |

```bash
docker compose up -d                                              # start PostgreSQL and MongoDB
docker exec -it marriott_postgres psql -U mit8103 -d marriott_crs # open the SQL shell
docker exec -it marriott_mongo mongosh                            # open the MongoDB shell
```

PostgreSQL uses port 5433 instead of the usual 5432 because another project on my laptop already
uses 5432.

## References

- Amadeus (n.d.) *Marriott International to deploy transformative CRS solution*. Available at: https://amadeus.com/en/newsroom/press-releases/marriott-international-to-deploy-transformative-crs-solution
- Business Traveller (2020) *Marriott International fined £18.4 million for data breach*. Available at: https://www.businesstraveller.com/business-travel/2020/11/02/marriott-international-fined-18-4-million-for-data-breach/
- Marriott International (2026) *Marriott International Reports Fourth Quarter and Full Year 2025 Results*. Available at: https://marriott.gcs-web.com/news-releases/news-release-details/marriott-international-reports-fourth-quarter-and-full-year-2025
- Marriott International (n.d.) *Hotels in Nigeria*. Available at: https://www.marriott.com/en/destinations/nigeria.mi
- MIVA Open University (2025) *MIT 8103 Advanced Database Systems*. Course material, Study Sessions One to Six.
- Reed, J. (2015) *Why Marriott is transforming their legacy systems with NoSQL*. diginomica. Available at: https://diginomica.com/why-marriott-is-transforming-their-legacy-systems-with-nosql
