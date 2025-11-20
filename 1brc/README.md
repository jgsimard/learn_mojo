# One Billion Row Challenge

## V0 : Basic


## V1 : Float -> Int


## V2 : SIMD 1


## Summary
Timings for 1_000_000 rows (ms)
| Version | What Changed ?                      | Timings | Improvement |
|---------|-------------------------------------|---------|-------------|
| v0      |                                     |658.0    |      1.0    |
| v1      |Parse Temperature as Int             |501.9    |      1.3    |
| v2      |SIMD parsing + Hash-based city lookup|122.5    |      5.4    |
| v3      |Improved SIMD with interleave        |123.4    |      5.3    |
| v4      |parallel (8 cores)                   | 59.8    |     11.0    |
| v5      |Memory mapped file (MMap)            | 18.6    |     35.4    |
| v6      |if-else -> try-catch                 | 12.1    |     54.4    |


