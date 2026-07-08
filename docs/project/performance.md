# Performance Evidence

gcode is designed for terminal hot paths, but performance claims should be tied
to current benchmark output and runner metadata.

## Current Policy

- Avoid "fastest" claims until comparisons are reproduced.
- Record Zig version, optimize mode, CPU, OS, table version, and input corpus.
- Keep benchmark thresholds informational until low-noise metrics are proven.
- Compare against specific versions of zg, ziglyph, and stdlib helpers.

## Benchmark Areas

- `getWidth` and `getProperties`
- `stringWidth`
- grapheme iteration
- word iteration
- UTF-8 validation/decode
- normalization
- table size and binary size
- mixed ASCII/CJK/emoji workloads

The current benchmark smoke reports:

- Unicode version and generated data-file count
- generated table stage entry counts
- width lookup time
- string width time per byte
- grapheme iteration time per cluster
- existing shaping-oriented workload timings

## Command

```bash
zig build benchmark
zig build bench-compare
```

Future work should add machine-readable benchmark output and external comparison
runs against pinned versions of zg and ziglyph.

## External Comparison Plan

`bench-compare` currently records local gcode corpus metrics and explicitly
reports external `zg` and `ziglyph` comparisons as not configured.

Do not publish comparison numbers until this plan is implemented:

1. Pin exact `zg` and `ziglyph` versions or commits.
2. Run equivalent workloads for lookup, string width, grapheme iteration, normalization, and UTF-8 validation.
3. Record CPU, OS, Zig version, optimize mode, and input corpus.
4. Store output in a machine-readable artifact.
5. Compare medians and variance, not one-off best runs.
