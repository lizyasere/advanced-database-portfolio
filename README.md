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
| Its old reservation system, Marsha, ran on one mainframe. In 2015 Marriott began moving it to a NoSQL database (Couchbase) to cut costs and scale out across data centres. | Portfolio 4 |
| In 2021 it agreed to replace its own reservation system with Amadeus's cloud based central reservation system. By September 2025 its new cloud reservation, property and loyalty systems were being trialled at six hotels, with a phased rollout planned over 18 months. | Portfolio 5 |
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
| `portfolio-4-nosql/` | Document, key-value and graph models of the same Marriott data (MongoDB and Neo4j) | Complete |
| `portfolio-5-distributed-cloud/` | Replication, failover, sharding by region, distributed transactions and a MongoDB Atlas cloud deployment | Complete |
| `docs/` | Final documentation submitted on the LMS (PDF) and detailed reflection notes | Complete |
| `screenshots/` | Screenshots used as evidence across all portfolios | |

## Link to the course study sessions

| Study session | Main topics | Where I applied it |
|---|---|---|
| One: Review of Traditional Relational Databases and Advanced Concepts | Design stages, characteristics of a good database, normalisation (1NF to BCNF) | Portfolio 1: followed the design stages from requirements to testing, normalised a flat booking sheet to BCNF, and kept two columns denormalised on purpose |
| Two: Distributed Database System | Fragmentation, replication, consistency, CAP theorem, ACID vs BASE | Portfolio 3: tested all four ACID properties, including a crash test for durability. Portfolio 4: a multi-night booking in a key-value store that gives nights back instead of using a transaction (BASE). Portfolio 5: a three-node replica set (replication lag, write concerns, stale reads, failover and a network partition), bookings sharded by region as horizontal fragmentation, and multi-document transactions |
| Three: Big Data and Cloud Database Systems | Cloud databases and their uses, data warehouses, security | Portfolio 5: the Marriott booking data loaded into MongoDB Atlas, with local and cloud response times compared and the cloud features (scaling, high availability, managed backups) checked against the free tier |
| Four: Query Optimisation in Database | Cost-based optimisation, execution plans, cost estimation, indexing and file organisation | Portfolio 2: read execution plans, compared estimated and actual rows, added partial, expression and covering indexes, and measured their cost |
| Five: Emerging Trends in Database Systems | Graph databases, serverless and edge databases | Portfolio 4: a graph of guests, hotels, cities and countries in Neo4j, queried in Cypher for recommendations and link analysis, and compared with the same questions in SQL |
| Six: Introduction to Data Security and Data Privacy | Privacy challenges, privacy by design | Portfolio 1: no passport numbers or full card numbers stored, based on the Starwood breach |

## Setup

Everything runs in Docker, so anyone can rebuild the same environment on their own machine.

| Tool | Version |
|---|---|
| PostgreSQL | 16.4 (image `postgres:16.4`, on host port 5433) |
| MongoDB | 7.0.14 (image `mongo:7.0.14`, on host port 27017) |
| Neo4j | 5.26.0 Community (image `neo4j:5.26.0-community`, browser on http://127.0.0.1:7474) |
| Docker Engine and Compose | 29.6.1 and v5.1.4 |

```bash
docker compose up -d                                              # start PostgreSQL, MongoDB and Neo4j
docker exec -it marriott_postgres psql -U mit8103 -d marriott_crs # open the SQL shell
docker exec -it marriott_mongo mongosh                            # open the MongoDB shell
docker exec -it marriott_neo4j cypher-shell -u neo4j -p mit8103_pass  # open the Neo4j shell
```

PostgreSQL uses port 5433 instead of the usual 5432 because another project on my laptop already
uses 5432.

## References

- Amadeus (2021) *Amadeus Announces Agreement with Marriott International to Deploy Transformative, Cloud-based CRS Solution*. Available at: https://amadeus.com/en/newsroom/press-releases/marriott-international-to-deploy-transformative-crs-solution
- Business Traveller (2020) *Marriott International fined £18.4 million for data breach*. Available at: https://www.businesstraveller.com/business-travel/2020/11/02/marriott-international-fined-18-4-million-for-data-breach/
- Hotel Technology News (2025) *Marriott Bets on Cloud-Native Platforms, AI Agents and Unified Guest Data to Power Smarter Hotel Operations*. Available at: https://hoteltechnologynews.com/2025/09/marriott-bets-on-cloud-native-platforms-ai-agents-and-unified-guest-data-to-power-smarter-hotel-operations/
- Marriott International (2026) *Marriott International Reports Fourth Quarter and Full Year 2025 Results*. Available at: https://marriott.gcs-web.com/news-releases/news-release-details/marriott-international-reports-fourth-quarter-and-full-year-2025
- Marriott International (n.d.) *Hotels in Nigeria*. Available at: https://www.marriott.com/en/destinations/nigeria.mi
- MIVA Open University (2025) *MIT 8103 Advanced Database Systems*. Course material, Study Sessions One to Six.
- Reed, J. (2015) *Why Marriott is transforming their legacy systems with NoSQL*. diginomica. Available at: https://diginomica.com/why-marriott-is-transforming-their-legacy-systems-with-nosql
