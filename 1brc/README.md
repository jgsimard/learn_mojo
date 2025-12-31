# One Billion Row Challenge
Goal : be faster than polars


## Summary
Timings for 1_000_000 rows (ms)

| Version | What Changed ? | Timings | Vs Polars | Vs previous | Vs v0 |
|---|---|---|---|---|---|
| polars |                          | 12.0  | 1.00  | -     | 11.3 |
| v0 |                              | 135.5 | 0.09  | -     | 1.0 |
| v1 | Parse Temperature as Int     | 112.5 | 0.11  | 1.2   | 1.2 |
| v2 | Hash-based city lookup       | 92.2  | 0.13  | 1.2   | 1.5 |
| v3 | SIMD temperature parsing     | 19.3  | 0.62  | 4.8   | 7.0 |
| v4 | parallel (8 cores)           | 6.6   | 1.82  | 2.9   | 20.5 |
| v5 | Memory mapped file (MMap)    | 2.5   | 4.80  | 2.7   | 54.2 |
