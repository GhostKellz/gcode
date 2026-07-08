# Support Matrix

| Surface | Status | Notes |
|---|---|---|
| UTF-8 validation/decode/encode wrappers | Usable | Thin wrappers over Zig stdlib behavior. |
| Width lookup | Usable, needs official fixtures | Covered by local terminal fixtures and explicit ambiguous-width policy tests; still needs official conformance. |
| Grapheme iteration | Usable, needs official conformance | Covered by local terminal fixtures; still needs official GraphemeBreakTest coverage before v1.0. |
| TerminalString helpers | Usable, new | Provides grapheme-safe cursor, slicing, truncation, and deletion helpers for terminal consumers. |
| Word iteration | Partial | Covered by local terminal fixtures; still needs official WordBreakTest coverage. |
| Case mapping | Partial | Covered by local basics; still needs SpecialCasing/CaseFolding policy and tests. |
| Normalization | Partial | Covered by local basics; still needs NormalizationTest coverage and idempotence tests. |
| BiDi | Experimental | Class lookup uses generated data, but the full algorithm still needs conformance and downstream validation. |
| Script detection | Experimental | Useful for shaping guidance; not a stable shaping contract. |
| Text shaping | Experimental | Belongs at the boundary with zfont; not HarfBuzz parity. |
| Advanced script helpers | Experimental | Needs fixtures and documented limitations. |
| Code generation | Partial | Needs pinned data/checksum workflow and table freshness checks. |
| Benchmarks | Informational | Local benchmark smoke records table sizes and terminal workloads; external comparisons remain future work. |

The `zig build test-api-guard` target force-references the current terminal API
candidate so downstream-facing names do not drift silently.

## Promotion Criteria

A surface should move toward stable only when it has:

- official Unicode fixture coverage where applicable
- deterministic generated table metadata
- positive and negative tests
- documented width/segmentation policy
- downstream validation with Phantom, zfont, or Ghostshell-like consumers
