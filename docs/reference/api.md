# API Reference

This page summarizes the current root API exported from `src/lib.zig`.

## Terminal-Oriented Core

- `unicode_version` - Unicode data version used by the checked-in generated tables.
- `unicode_data_files` - source data files represented in the checked-in generated tables.
- `getProperties(cp)` - returns packed Unicode properties for a codepoint.
- `getWidth(cp)` - returns terminal display width for a codepoint.
- `getWidthWithPolicy(cp, policy)` - returns terminal width with explicit ambiguous-width policy.
- `stringWidth(bytes)` - grapheme-aware display width for UTF-8 input, skipping malformed sequences.
- `stringWidthWithPolicy(bytes, policy)` - grapheme-aware string width with explicit ambiguous-width policy.
- `isZeroWidth(cp)`, `isWide(cp)`, `isNarrow(cp)` - convenience width classifiers.
- `isControlCharacter(cp)`, `isDisplayableInTerminal(cp)` - terminal filtering helpers.

## UTF-8 Helpers

```zig
pub const utf8 = struct {
    pub fn validate(bytes: []const u8) bool
    pub fn decode(bytes: []const u8) !u21
    pub fn encode(codepoint: u21, buffer: []u8) !u3
    pub fn codepointCount(bytes: []const u8) !usize
    pub fn byteSequenceLength(codepoint: u21) !u3
};
```

## Grapheme And Word Helpers

- `graphemeIterator(bytes)` - iterates grapheme clusters over UTF-8 text.
- `GraphemeIterator`, `ReverseGraphemeIterator` - forward and reverse cluster iterators.
- `findPreviousGrapheme(text, pos)`, `findNextGrapheme(text, pos)` - cursor movement helpers.
- `wordIterator(bytes)`, `WordIterator`, `ReverseWordIterator` - word segmentation helpers.

## TerminalString Helpers

- `TerminalString.init(bytes)` - borrowed terminal string wrapper.
- `displayWidth()` - display width in terminal cells.
- `nextBoundary(byte_index)` / `previousBoundary(byte_index)` - grapheme-safe cursor movement.
- `graphemeAt(index)` - returns byte span and width for a grapheme index.
- `sliceGraphemes(start, count)` - byte slice by grapheme index.
- `truncateWidth(max_width)` - grapheme-safe truncation by display width.
- `deletePrevious(byte_index)` - returns the previous grapheme cluster bytes.

`TerminalString` borrows the input bytes. It does not allocate, and returned
slices point into the original input.

`TerminalString.initWithPolicy(bytes, policy)` applies an explicit East Asian
Ambiguous width policy to width and truncation operations.

## Case And Normalization

- `toLower(cp)`, `toUpper(cp)`, `toTitle(cp)` - codepoint case mapping.
- `normalize(allocator, bytes, form)` - allocation-returning normalization helper.
- `isNormalized(bytes, form)` - normalization check.
- `NormalizationForm` - `nfc`, `nfd`, `nfkc`, `nfkd`.

## Partial / Experimental APIs

The root also exports BiDi, script detection, shaping, and advanced script types.
These are useful for experiments, but should not be treated as stable or complete
until official conformance fixtures and downstream integration tests cover them.

Examples include:

- `BiDi`, `BiDiClass`, `reorderForDisplay`, `calculateCursorPosition`
- `ScriptDetector`, `ShapingInfo`, `requiresSpecialTerminalHandling`
- `TextShaper`, `TerminalShaper`, `AdvancedShaper`
- `ComplexScriptAnalyzer`, `ArabicJoining`, `IndicSyllable`, `EmojiSequence`

## Ownership

Core width/property helpers do not allocate. APIs that return allocated slices
must be freed by the caller with the allocator used to create them.
