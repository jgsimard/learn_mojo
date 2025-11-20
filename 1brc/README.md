# One Billion Row Challenge
Goal : be faster than polars


## Summary
Timings for 1_000_000 rows (ms)

| Version | What Changed ? | Timings | Vs Polars | Vs previous | Vs v0 |
|---|---|---|---|---|---|
| polars | | 54.5 | - | - | 9.6 |
| v0 | | 523.7 | 0.1 | - | 1.0 |
| v1 | Parse Temperature as Int | 409.1 | 0.1 | 1.3 | 1.3 |
| v2 | SIMD parsing + Hash-based city lookup | 115.0 | 0.5 | 3.6 | 4.6 |
| v3 | Improved SIMD with interleave | 115.7 | 0.5 | 1.0 | 4.5 |
| v4 | parallel (8 cores) | 59.0 | 0.9 | 2.0 | 8.9 |
| v5 | Memory mapped file (MMap) | 17.1 | 3.2 | 3.5 | 30.6 |
| v6 | if-else -> try-catch | 11.0 | 5.0 | 1.6 | 47.6 |