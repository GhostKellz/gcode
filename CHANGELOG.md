# Changelog

All notable changes to gcode will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
