# Write cost: inserting 50,000 bookings (4 runs each, rolled back)

## With the Portfolio 2 indexes
    Time: 3161.492 ms (00:03.161)
    Time: 1798.133 ms (00:01.798)
    Time: 1986.313 ms (00:01.986)
    Time: 2378.966 ms (00:02.379)

## Without the Portfolio 2 indexes
    Time: 1788.021 ms (00:01.788)
    Time: 1758.964 ms (00:01.759)
    Time: 1727.861 ms (00:01.728)
    Time: 1687.430 ms (00:01.687)

Median with: 2,182 ms. Median without: 1,743 ms. About 25% slower with the extra indexes.
