# Terminal Emulator Integration Guide

This guide explains how to integrate gcode into terminal emulators for optimal Unicode text processing.

## Overview

Terminal emulators need precise Unicode handling for:
- Character width calculation (narrow/wide/double-width)
- Grapheme cluster detection (cursor movement)
- Text selection and editing
- Display rendering

gcode provides all these capabilities with terminal-optimized performance.

## Quick Start

```zig
const gcode = @import("gcode");

// Character width for rendering
const width = gcode.getWidth('한'); // Returns: 2 (double-width)

// Grapheme boundaries for cursor movement
var state = gcode.GraphemeBreakState{};
const is_boundary = gcode.isGraphemeBoundary('e', '́', &state);

// String width calculation
const display_width = gcode.stringWidth("Hello 世界!");
```

## Character Width Calculation

Terminal emulators must handle different character widths correctly:

```zig
pub fn renderCharacter(cp: u21) void {
    const width = gcode.getWidth(cp);
    switch (width) {
        0 => {}, // Zero-width (combining marks, control chars)
        1 => renderNarrow(cp),
        2 => renderWide(cp),
    }
}
```

### Width Categories

- **0**: Zero-width characters (combining marks, control codes)
- **1**: Narrow characters (most ASCII, Latin, Cyrillic)
- **2**: Wide characters (CJK, fullwidth forms, emoji)

## Grapheme Cluster Detection

For proper cursor movement and text selection:

```zig
pub fn moveCursorRight(text: []const u8, cursor_pos: usize) usize {
    var state = gcode.GraphemeBreakState{};
    var pos = cursor_pos;

    while (pos < text.len) {
        const cp = try gcode.utf8.decode(text[pos..]);
        pos += gcode.utf8.codepointLength(cp);

        if (gcode.isGraphemeBoundary(cp, getNextCodepoint(text, pos), &state)) {
            break;
        }
    }

    return pos;
}
```

## Text Selection

```zig
pub fn selectGraphemeCluster(text: []const u8, start_pos: usize) []const u8 {
    var iter = gcode.graphemeIterator(text);
    var current_pos: usize = 0;

    while (iter.next()) |cluster| {
        const cluster_end = current_pos + cluster.len;
        if (start_pos >= current_pos && start_pos < cluster_end) {
            return cluster;
        }
        current_pos = cluster_end;
    }

    return "";
}
```

## Case Conversion

For terminal applications that need case-insensitive operations:

```zig
pub fn caseInsensitiveSearch(text: []const u8, pattern: []const u8) bool {
    // Convert both to lowercase for comparison
    var text_lower: [text.len]u8 = undefined;
    var pattern_lower: [pattern.len]u8 = undefined;

    // Note: This is simplified - real implementation needs proper UTF-8 handling
    for (text, 0..) |c, i| {
        text_lower[i] = gcode.toLower(c);
    }
    for (pattern, 0..) |c, i| {
        pattern_lower[i] = gcode.toLower(c);
    }

    return std.mem.indexOf(u8, &text_lower, &pattern_lower) != null;
}
```

## Performance Considerations

### Memory Layout

gcode's 3-level lookup tables are cache-friendly:

```zig
// Hot path: 2-3 cache lines accessed
const props = gcode.getProperties(cp);
// Stage 1: block lookup
// Stage 2: sub-block lookup
// Stage 3: property retrieval
```

### Zero Allocation

All core functions are allocation-free:

```zig
// ✅ Zero allocation
const width = gcode.getWidth(cp);
const props = gcode.getProperties(cp);

// ✅ Iterator-based (no allocation)
var iter = gcode.graphemeIterator(text);
```

### SIMD Opportunities

For bulk operations, consider SIMD processing:

```zig
pub fn countWideCharacters(text: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        const cp = gcode.utf8.decode(text[i..]) catch break;
        if (gcode.getWidth(cp) == 2) count += 1;
        i += gcode.utf8.codepointLength(cp);
    }

    return count;
}
```

## Integration Checklist

- [ ] Character width calculation in rendering engine
- [ ] Grapheme boundary detection for cursor movement
- [ ] Text selection respects grapheme clusters
- [ ] Input handling supports combining characters
- [ ] Search functions use Unicode case folding
- [ ] Performance benchmarks vs current implementation
- [ ] Memory usage profiling
- [ ] Unicode compliance testing

## Common Pitfalls

### Double-Width Character Handling

```zig
// ❌ Wrong: assumes all characters are 1 column
cursor_x += 1;

// ✅ Correct: use actual character width
cursor_x += gcode.getWidth(current_char);
```

### Grapheme vs Codepoint Iteration

```zig
// ❌ Wrong: moves by codepoints, breaks combining characters
cursor_pos += 1;

// ✅ Correct: move by grapheme clusters
cursor_pos = moveCursorRight(text, cursor_pos);
```

### String Width Calculation

```zig
// ❌ Wrong: byte length ≠ display width
display_width = text.len;

// ✅ Correct: sum character widths
display_width = gcode.stringWidth(text);
```

## Testing

Use Unicode test files for validation:

```zig
test "Unicode compliance" {
    // Test against Unicode test files
    const test_data = @embedFile("unicode/GraphemeBreakTest.txt");
    // Parse and validate against gcode implementation
}
```

## Migration from Other Libraries

### From zg/ziglyph

```zig
// Old (zg)
const width = zg.displayWidth(cp);

// New (gcode)
const width = gcode.getWidth(cp);
```

### From std.unicode

```zig
// Old (std.unicode)
const is_boundary = std.unicode.isGraphemeBoundary(a, b);

// New (gcode) - stateful for better performance
var state = gcode.GraphemeBreakState{};
const is_boundary = gcode.isGraphemeBoundary(a, b, &state);
```

## Performance Targets

For terminal emulators, gcode targets:

- **Character width lookup**: < 2ns
- **Grapheme boundary check**: < 5ns
- **Memory usage**: < 500KB
- **Cold start time**: < 10ms

These targets ensure terminals remain responsive even with complex Unicode text.</content>
<parameter name="filePath">/data/projects/gcode/docs/terminal-emulator-integration.md