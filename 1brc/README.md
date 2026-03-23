# One Billion Row Challenge
Goal : be faster than polars


## Summary
Timings for 1_000_000 rows (ms)

| Version | What Changed ? | Timings | Vs Polars | Vs previous | Vs v0 |
|---|---|---|---|---|---|
| polars |                          | 12.0  | 1.00  | -     | 11.3 |
| v0 |                              | 134.6 | 0.09  | -     |  1.0 |
| v1 | Parse Temperature as Int     | 114.9 | 0.11  | 1.2   |  1.2 |
| v2 | Hash-based city lookup       | 93.3  | 0.13  | 1.2   |  1.4 |
| v3 | SIMD temperature parsing     | 13.6  | 0.88  | 6.9   |  9.9 |
| v4 | parallel (8 cores)           | 6.2   | 1.93  | 2.2   | 21.7 |
| v5 | Memory mapped file (MMap)    | 1.9   | 6.31  | 3.3   | 70.8 |
