# Unicode Data

gcode uses generated Unicode tables checked into `src/unicode_tables.zig`.
The checked-in tables currently declare `unicode_version = "16.0.0"` and expose
the generated source file list as `unicode_data_files` from the root module.

## Current Goals

- pin Unicode source files and version metadata
- record checksums for generated data inputs
- make `zig build gen` reproducible
- add a codegen-check mode that verifies checked-in generated tables are current
- keep generated tables compact and auditable

## Data Sources To Track

- `UnicodeData.txt`
- `EastAsianWidth.txt`
- `GraphemeBreakProperty.txt`
- `GraphemeBreakTest.txt`
- `WordBreakProperty.txt`
- `WordBreakTest.txt`
- `NormalizationTest.txt`
- `SpecialCasing.txt`
- `CaseFolding.txt`
- emoji data files relevant to ZWJ and presentation behavior

## Current Generated Metadata

- `UnicodeData.txt`
- `EastAsianWidth.txt`
- `GraphemeBreakProperty.txt`
- `WordBreakProperty.txt`
- `Scripts.txt`
- `DerivedBidiClass.txt`
- `emoji-data.txt`

## Checked Test Fixtures

Small official-format samples live under `src/testdata/unicode/` and are exercised by
`zig build test`:

- `grapheme-break-sample.txt`
- `word-break-sample.txt`
- `east-asian-width-sample.tsv`
- `normalization-sample.tsv`
- `case-mapping-sample.tsv`

These are scaffolding for full upstream Unicode conformance files, not a complete
replacement for them.

Full-file placeholders live under `src/testdata/unicode/full/` and are exercised
by `zig build conformance`. Running `zig build gen` downloads pinned UCD 16.0.0
copies of `GraphemeBreakTest.txt`, `WordBreakTest.txt`, and
`NormalizationTest.txt` into that directory. `EastAsianWidth.txt` is already one
of the generator inputs and should be mirrored there when replacing the
placeholder with the full upstream file.

## Review Rules

Generated table changes should include:

- Unicode version
- source URLs
- input checksums
- generator command
- summary of changed table sizes
- test results
