# Terminal Integration

Terminals and TUIs need consistent display width, cursor movement, selection, and
input validation. gcode is currently strongest on these terminal-oriented APIs.

## Width

```zig
pub fn cellWidth(cp: u21) usize {
    return gcode.getWidth(cp);
}
```

Do not use byte length or codepoint count as display width. Use `stringWidth` or
grapheme-aware logic for text layout.

`stringWidth` is grapheme-aware for common terminal emoji clusters, including ZWJ
emoji, regional-indicator flags, keycaps, and emoji modifier sequences.

Use `getWidthWithPolicy` or `stringWidthWithPolicy` when your terminal needs
East Asian Ambiguous characters to render as wide instead of narrow.

## Cursor Movement

```zig
pub fn moveRight(text: []const u8, pos: usize) usize {
    return gcode.findNextGrapheme(text, pos);
}

pub fn moveLeft(text: []const u8, pos: usize) usize {
    return gcode.findPreviousGrapheme(text, pos);
}
```

Cursor movement should not split combining sequences, emoji sequences, or other
grapheme clusters.

`findPreviousGrapheme` and `findNextGrapheme` are covered by local fixtures for
combining marks and emoji ZWJ clusters.

## TerminalString

Use `TerminalString` when you need several terminal-safe operations over the same
borrowed byte slice:

```zig
const text = gcode.TerminalString.init("a界e\u{0301}");
const width = text.displayWidth();
const first_two = text.sliceGraphemes(0, 2);
const clipped = text.truncateWidth(3);
_ = .{ width, first_two, clipped };
```

## Recommended Test Strings

- `hello`
- `Hello 世界`
- `e\u{301}`
- `👨‍👩‍👧‍👦`
- `🏳️‍🌈`
- `🇺🇸🇯🇵`
- mixed Arabic/Hebrew/Latin text

The normal `zig build test` suite includes local terminal fixtures for width,
grapheme, cursor, word, case, and normalization behavior. Official Unicode
conformance files are still a separate v1.0 task.

`zig build conformance` runs official-format fixture files under
`src/testdata/unicode/full/`.

## Known Gaps

- full official width conformance fixtures still need to be wired in
- BiDi support is experimental
- shaping APIs should be validated with zfont before being treated as stable
- official Unicode conformance fixtures are still needed for v1.0
