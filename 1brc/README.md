# One Billion Row Challenge
Goal : be faster than polars


## Summary
Timings for 10_000_000 rows (ms)

| Version | What Changed ?                      | Time (ms)| Vs Polars | Vs previous | Vs v0 |
| ------- | -------------------------           | ------: | --------: | ----------- | ----- |
| polars  |                                     | 120.0   | 1.00×     | -           | 11.3  |
| v0      |                                     | 1416.3  | 0.08×     | -           | 1.0   |
| v1      | Parse Temperature as Int            | 1034.8  | 0.12×     | 1.4         | 1.4   |
| v2      | Hash-based city lookup              | 928.0   | 0.13×     | 1.1         | 1.5   |
| v3      | SIMD temperature parsing            | 188.8   | 0.64×     | 4.9         | 7.5   |
| v4      | parallel (8 cores)                  | 84.8    | 1.42×     | 2.2         | 16.7  |
| v5      | Memory mapped file (MMap)           | 13.0    | 9.23×     | 6.5         | 108.9 |
| v6      | Unchecked sign-byte load            | 14.0    | 8.57×     | 0.9         | 101.2 |
| v7      | Fixed-size pre-hashed station table | 11.7    | 10.26×    | 1.2         | 121.1 |
| v9      | Unchecked fixed-table access        | 10.1    | 11.88×    | 1.2         | 140.2 |
| v10     | Compact 24-byte aggregation entries | 9.0     | 13.33×    | 1.1         | 157.4 |
