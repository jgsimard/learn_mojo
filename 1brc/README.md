# One Billion Row Challenge
Goal : be faster than polars


## Summary
Timings for 1_000_000 rows (ms)

| Version | What Changed ? | Timings | Vs Polars | Vs previous | Vs v0 |
|---|---|---|---|---|---|
| polars |                          | 12.0  | 1.00  | -     | 11.3 |
| v0 |                              | 133.4 | 0.09  | -     |  1.0 |
| v1 | Parse Temperature as Int     | 106.9 | 0.11  | 1.2   |  1.2 |
| v2 | Hash-based city lookup       | 87.0  | 0.14  | 1.2   |  1.5 |
| v3 | SIMD temperature parsing     | 13.5  | 0.89  | 6.4   |  9.9 |
| v4 | parallel (8 cores)           | 5.5   | 2.18  | 2.5   | 24.3 |
| v5 | Memory mapped file (MMap)    | 1.5   | 8.00  | 3.7   | 88.9 |
