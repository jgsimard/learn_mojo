# One Billion Row Challenge
Goal : be faster than polars


## Summary
Timings for 1_000_000 rows (ms)

| Version | What Changed ? | Timings | Vs Polars | Vs previous | Vs v0 |
|---|---|---|---|---|---|
| polars | | 54.5 | 1.00 | - | 9.1 |
| v0 | | 496.1 | 0.11 | - | 1.0 |
| v1 | Parse Temperature as Int | 392.9 | 0.14 | 1.3 | 1.3 |
| v2 | Hash-based city lookup | 342.6 | 0.16 | 1.1 | 1.4 |
| v3 | SIMD temperature parsing | 82.4 | 0.66 | 4.2 | 6.0 |
| v4 | parallel (8 cores) | 40.6 | 1.35 | 2.0 | 12.3 |
| v5 | Memory mapped file (MMap) | 10.0 | 5.45 | 4.0 | 49.6 |
