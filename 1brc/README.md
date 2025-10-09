# One Billion Row Challenge

## V0 : Basic


## V1 : Float -> Int


## V2 : SIMD 1


## Summary
Timings for 1_000_000 rows (ms)
| Version | What Changed ?                      | Timings | Improvement |
|---------|-------------------------------------|---------|-------------|
| v0      |                                     |161.1    |      1.0    |
| v1      |Parse Temperature as Int             |130.3    |      1.2    |
| v2      |SIMD                                 | 73.0    |      2.2    |
| v3      |less string                          | 48.3    |      3.3    |
| v4      |register_passable + contains in Dict | 31.5    |      5.1    |
| v5      |SIMD 2                               | 31.4    |      5.1    |
| v6      |parallel (8 cores)                   |  9.4    |     17.2    |
| v4      |Memory mapped file (MMap)            |  4.5    |     35.8    |


