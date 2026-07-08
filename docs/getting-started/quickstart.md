# Quickstart

These examples use the current terminal-facing API without implying full Unicode
conformance or stable v1.0 status.

## Character Width

```zig
const gcode = @import("gcode");

const ascii_width = gcode.getWidth('A');
const cjk_width = gcode.getWidth('中');
const total = gcode.stringWidth("Hello 世界");
_ = .{ ascii_width, cjk_width, total };
```

## Grapheme Movement

```zig
const gcode = @import("gcode");

const text = "e\u{301}cho";
const next = gcode.findNextGrapheme(text, 0);
const prev = gcode.findPreviousGrapheme(text, next);
_ = .{ next, prev };
```

## UTF-8 Helpers

```zig
const gcode = @import("gcode");

if (!gcode.utf8.validate(input)) return error.InvalidUtf8;
const cp = try gcode.utf8.decode(input);
```

## Iteration

```zig
var iter = gcode.graphemeIterator("Hello 🏳️‍🌈");
while (iter.next()) |cluster| {
    _ = cluster;
}
```

Validate behavior against your own terminal width policy while gcode remains
experimental.
