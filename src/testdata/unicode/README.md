# Vendored Unicode conformance fixtures

These are the unmodified upstream Unicode Character Database (UCD) conformance
files, pinned to **UCD 16.0.0** (matching `unicode_version` in the generated
tables). They are embedded into the conformance runner via `@embedFile` and are
the source of truth for correctness — do not edit by hand.

## Sources

| File | Source URL |
|------|------------|
| `GraphemeBreakTest.txt` | https://www.unicode.org/Public/16.0.0/ucd/auxiliary/GraphemeBreakTest.txt |
| `WordBreakTest.txt` | https://www.unicode.org/Public/16.0.0/ucd/auxiliary/WordBreakTest.txt |
| `NormalizationTest.txt` | https://www.unicode.org/Public/16.0.0/ucd/NormalizationTest.txt |
| `EastAsianWidth.txt` | https://www.unicode.org/Public/16.0.0/ucd/EastAsianWidth.txt |
| `emoji-test.txt` | https://www.unicode.org/Public/emoji/16.0/emoji-test.txt |

## Checksums (sha256)

Verify with `sha256sum -c CHECKSUMS.txt` from this directory.

## Updating

Bump the version in the URLs above, re-download, refresh `CHECKSUMS.txt`
(`sha256sum *.txt > CHECKSUMS.txt`), and keep it in lockstep with the UCD version
used by `zig build gen`.
