# Changelog

All notable changes to gcode will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.6] - 2026-07-08

### Added

- **Full UCD 16.0.0 conformance** - `zig build conformance` runs the vendored
  official Unicode test corpus through a shared harness: grapheme (1093/1093),
  word (1826/1826), normalization (19965/19965), emoji (3781/3781), and East
  Asian Width (2643/2643), all at 100%. Per-suite failure budgets are ratcheted
  to zero so CI fails on any regression; `--strict` requires zero failures.
- **UAX #15 normalization** - `src/normalize.zig` reimplements NFC/NFD/NFKC/NFKD
  against generated one-level decomposition and canonical composition tables
  (`src/normalize_data.zig`) with algorithmic Hangul (de)composition, canonical
  ordering, and composition blocking. Replaces the previous hand-maintained stub.
- **UAX #29 GB9c Indic conjunct clustering** - `src/incb.zig` classifies
  `Indic_Conjunct_Break` (Consonant/Linker/Extend) from generated range tables so
  `Consonant [Extend Linker]* Linker [Extend Linker]* × Consonant` clusters hold.
- **Codegen emits normalization + InCB tables** - `zig build gen` now downloads
  `DerivedCoreProperties.txt` and `CompositionExclusions.txt` and regenerates
  `src/incb.zig` and `src/normalize_data.zig` from pinned UCD 16.0.0 data, so both
  files are reproducible rather than hand-maintained.
- **`TerminalString`** - grapheme-safe cursor movement, slicing, truncation, and
  deletion over borrowed UTF-8 text (`src/terminal_string.zig`).
- **API guard tests** - `src/api_guard.zig` force-references the v1.0-candidate
  terminal surface so downstream Phantom/Ghostshell names cannot drift silently.
- **`zig build verify`** - runs build, tests, API guard, and benchmark smoke; a
  `bench-compare` scaffold records corpus metrics and reports external comparisons
  as not configured.
- **Fixtures** - local conformance-style, terminal, downstream (Phantom/Ghostshell),
  and property/fuzz fixtures (UTF-8 round trips, normalization idempotence).
- **Ambiguous-width policy** - APIs to treat East Asian Ambiguous characters as
  narrow or wide.

### Changed

- **`stringWidth` measures grapheme clusters as terminal cells** for emoji ZWJ,
  flags, keycaps, and emoji-modifier sequences instead of summing codepoint widths.
- **BiDi class lookup** routes through generated table data.
- **Generated tables expose metadata** - Unicode version and source data-file
  information are reachable from the root API and recorded in benchmark output.
- **Docs** - restructured into a single `docs/README.md` index plus lowercase
  section docs; README/docs mark the project experimental and drop unproven
  performance claims.
- **Toolchain** - bumped `minimum_zig_version` to `0.17.0-dev.1257+67b05e521` and
  the package version to `0.1.6`; `build.zig.zon` package paths include `docs`.

### Fixed

- **NFC buffer corruption** during recomposition.
- **Terminal cursor/format controls** - zero-width format controls and
  previous-grapheme cursor movement across emoji ZWJ clusters.

## [0.1.5] - 2026-06-04

### Added

- **Table-backed Script + BiDi classification** - `getScript`/`getBiDiClass` now read
  from the generated 3-stage lookup table instead of hand-rolled block-range
  approximations. `Script` (full UCD 16.0.0 script set) and `BiDiClass` (23 classes)
  are canonical enums in `properties.zig`, embedded per-codepoint in `Properties`, and
  re-exported from `script.zig`/`bidi.zig` for API stability
- **Emoji `Extended_Pictographic`** - Generator now parses `emoji/emoji-data.txt`
  (Extended_Pictographic, Emoji_Modifier, Emoji_Modifier_Base) and injects the
  grapheme boundary class, so emoji ZWJ sequences cluster correctly
- **Generator parsers** - `parseScripts` (Scripts.txt), `parseBidiClass`
  (extracted/DerivedBidiClass.txt, honoring `@missing` block defaults for unassigned
  Arabic/Hebrew ranges), and `parseEmojiData`; all UCD downloads pinned to 16.0.0 for
  reproducibility

### Changed

- **Zig 0.17.0-dev compatibility** - Updated for newer Zig 0.17.0-dev API changes
  - `build.zig`: replaced removed `b.args` passthrough with `run_cmd.addPassthruArgs()`
  - `@typeInfo(...).@"enum"` now exposes `field_names` instead of `fields` (grapheme break table precompute)
  - Replaced removed `std.meta.fields` with `std.meta.fieldNames`
- **Codegen revival** - `src/codegen/generator.zig` migrated to the new `std.Io` API
  (`std.Io.Threaded`, `std.process.run`, `Dir.readFileAlloc`/`createDirPath`/`writeFile`)
  and wired into the build via a `zig build gen` step
- **Regenerated `src/unicode_tables.zig`** - Rebuilt from pinned UCD 16.0.0 data; the
  deduplicated bucket count grew (3050 → 3778) to carry the new script/bidi/emoji
  payload and the corrected East Asian Width data
- **Toolchain** - Bumped `minimum_zig_version` to `0.17.0-dev.667+0569f1f6a` and the
  package version to `0.1.5` in `build.zig.zon`

### Fixed

- **generator.zig** - Repaired corrupted `LineBreakClass` enum and removed dead old-API
  declarations (`Properties.format`, `parseComposition`, `Composition`)
- **properties.zig** - Removed `Properties.format`, which referenced the removed
  `std.fmt.FormatOptions` and the old format-method signature (latent, unused)
- **benchmark.zig** - Reworked a long test string to avoid the `++`/`**` operator
  combination rejected by the current compiler
- **GB11 emoji clustering** - Family/profession ZWJ emoji (e.g. 👨‍👩‍👧, 👩‍💻) now
  iterate as a single grapheme cluster; previously broken because the table contained
  zero `Extended_Pictographic` entries (the property lives in `emoji-data.txt`, not
  `GraphemeBreakProperty.txt`)
- **East Asian Width parser** - `parseEastAsianWidth` never stripped the trailing
  `# category` comment, so the width value never matched `W`/`F`; the generated table
  had zero wide entries and all CJK code points were classified width 1. Now strips the
  comment, restoring correct double-width for CJK (95 wide buckets)

### Removed

- **src/root.zig** - Leftover `zig init` scaffolding (`bufferedPrint`/`add`), never imported
- **src/codegen/fetch_unicode.zig** - Dead, broken (removed `std.mem.split`, old
  `std.process.Child.init`) duplicate of the downloader/parsers already in `generator.zig`
- **src/lut.zig** - Dead, broken `Generator` (old `ArrayList.init`) and `Tables.writeZig`
  (old 3-arg `format`) rot; only the runtime `Tables`/`get()` lookup is used

### Formatting

- Ran `zig fmt` across the tracked source tree (`src/*.zig`, `src/codegen/*.zig`,
  `build.zig`)

## [0.1.3] - 2026-04-22

### Changed

- **Zig 0.17.0-dev compatibility** - Full compatibility with Zig 0.17.0-dev API changes
  - Updated `std.testing.Smith` fuzz API (now uses `*Smith` with `smith.bytes(&buf)`)
  - Replaced removed `std.posix.clock_gettime` with `std.os.linux.clock_gettime`
  - Updated `ArrayList` API (use `.empty` pattern, pass allocator to `deinit()`)
  - Fixed `Allocator.remap` vtable signature (5 parameters instead of 6)
  - Updated `std.debug.print` calls to require args tuple
  - Fixed format specifiers (`{d:>6.1}` instead of `{d:>6.1f}`)

### Fixed

- **bidi.zig** - Implemented UAX #9 weak type resolution (Rules W1-W7)
- **bidi.zig** - Implemented UAX #9 neutral type resolution (Rules N1-N2)
- **bidi.zig** - Fixed out-of-bounds access in FSI handling when at end of text
- **grapheme.zig** - `ReverseGraphemeIterator` now properly handles grapheme clusters instead of single codepoints
- **normalize.zig** - Fixed data corruption bug where NFC/NFKC composition read and wrote to same buffer
- **normalize.zig** - `combiningClass()` now uses actual Unicode combining class from properties table
- **normalize.zig** - `isNormalized()` now properly checks canonical ordering
- **normalize.zig** - Added canonical decomposition table for Latin-1 Supplement characters (À-ÿ)
- **normalize.zig** - `composeCanonical()` now performs reverse lookup in decomposition table
- **properties.zig** - Removed references to non-existent enum values in `GeneratorContext.get()`
- **lib.zig** - Removed redundant `cp != 0x7F` check in `isDisplayableInTerminal()`

### Added

- **SECURITY.md** - Security policy and vulnerability reporting guidelines
- **build.zig.zon** - Added LICENSE and README.md to package paths
- **normalize.zig** - Compatibility decomposition table (150+ mappings: superscripts, subscripts, ligatures, full-width chars, circled digits, fractions, Roman numerals)
- **grapheme.zig** - Comprehensive grapheme iterator tests (combining chars, emoji, regional indicators, Hangul, skin tone modifiers)
- **complex_script.zig** - Indic syllable position analysis (base consonants, pre/post-base elements, matras, nukta, virama, tone marks)

### Improved

- **normalize.zig** - `isCombiningMark()` now checks `combining_class > 0` in addition to grapheme_boundary_class

- **.gitignore** - Cleaned up and added generated tool binaries to ignore list
- **README.md** - Updated badges to `for-the-badge` style, updated Zig version to 0.17.0-dev

## [0.1.2] - 2025-09-27

### Added

- Initial v0.1.x release with core Unicode functionality
- Grapheme cluster boundary detection (UAX #29)
- Word boundary detection (UAX #29)
- BiDi algorithm implementation (UAX #9)
- Character width calculation for terminal emulators
- Script detection and complex script analysis
- Text shaping with ligature and kerning support
- Advanced shaping for Arabic, Indic, and emoji sequences
- Performance benchmarking suite
