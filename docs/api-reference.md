# API Reference

Complete API documentation for the gcode Unicode library.

## Core Functions

### Character Properties

```zig
pub fn getProperties(cp: u21) Properties
```

Returns comprehensive Unicode properties for a codepoint.

**Parameters:**
- `cp`: Unicode codepoint (0x0 to 0x10FFFF)

**Returns:** `Properties` struct containing:
- `width`: Display width (0, 1, or 2)
- `grapheme_boundary_class`: Grapheme break class
- `uppercase`: Uppercase mapping (0 if none)
- `lowercase`: Lowercase mapping (0 if none)
- `titlecase`: Titlecase mapping (0 if none)

**Example:**
```zig
const props = gcode.getProperties('a');
std.debug.print("Width: {}, Uppercase: U+{X}\n", .{
    props.width,
    props.uppercase,
});
```

---

```zig
pub fn getWidth(cp: u21) u2
```

Returns the display width of a character for terminal rendering.

**Parameters:**
- `cp`: Unicode codepoint

**Returns:** Width in terminal columns (0, 1, or 2)

**Example:**
```zig
const width = gcode.getWidth('한'); // Returns: 2
```

---

```zig
pub fn stringWidth(str: []const u8) usize
```

Calculates the total display width of a UTF-8 string.

**Parameters:**
- `str`: UTF-8 encoded string

**Returns:** Total width in terminal columns

**Example:**
```zig
const width = gcode.stringWidth("Hello 世界!"); // Returns: 9
```

## Case Conversion

```zig
pub fn toLower(cp: u21) u21
pub fn toUpper(cp: u21) u21
pub fn toTitle(cp: u21) u21
```

Convert a codepoint to lowercase, uppercase, or titlecase.

**Parameters:**
- `cp`: Unicode codepoint

**Returns:** Converted codepoint (or original if no mapping exists)

**Example:**
```zig
const upper = gcode.toUpper('a'); // Returns: 'A'
const lower = gcode.toLower('A'); // Returns: 'a'
```

## Grapheme Boundaries

```zig
pub const GraphemeBreakState = struct {
    // Internal state for grapheme boundary detection
};

pub fn isGraphemeBoundary(cp1: u21, cp2: u21, state: *GraphemeBreakState) bool
```

Determines if there's a grapheme boundary between two codepoints.

**Parameters:**
- `cp1`: First codepoint
- `cp2`: Second codepoint
- `state`: State object (maintain across calls for performance)

**Returns:** `true` if boundary exists

**Example:**
```zig
var state = gcode.GraphemeBreakState{};
const boundary = gcode.isGraphemeBoundary('e', '́', &state);
```

---

```zig
pub fn graphemeIterator(str: []const u8) GraphemeIterator
```

Creates an iterator over grapheme clusters in a string.

**Parameters:**
- `str`: UTF-8 encoded string

**Returns:** Iterator over grapheme clusters

**Example:**
```zig
var iter = gcode.graphemeIterator("Hello 🏳️‍🌈 World");
while (iter.next()) |cluster| {
    std.debug.print("Cluster: {s}\n", .{cluster});
}
```

## UTF-8 Utilities

```zig
pub const utf8 = struct {
    pub fn validate(str: []const u8) bool
    pub fn decode(str: []const u8) !u21
    pub fn encode(cp: u21, buffer: []u8) !usize
    pub fn codepointLength(cp: u21) usize
};
```

UTF-8 encoding/decoding utilities.

**Examples:**
```zig
// Validation
const valid = gcode.utf8.validate("🚀"); // true

// Decoding
const cp = try gcode.utf8.decode("🚀"); // 0x1F680

// Encoding
var buf: [4]u8 = undefined;
const len = try gcode.utf8.encode(0x1F680, &buf); // buf = "🚀"

// Codepoint length
const bytes = gcode.utf8.codepointLength('🚀'); // 4
```

## Normalization

```zig
pub const NormalizationForm = enum {
    nfc,  // Canonical Composition
    nfd,  // Canonical Decomposition
    nfkc, // Compatibility Composition
    nfkd, // Compatibility Decomposition
};

pub fn normalize(alloc: std.mem.Allocator, str: []const u8, form: NormalizationForm) ![]u8
pub fn isNormalized(str: []const u8, form: NormalizationForm) bool
```

Unicode text normalization.

**Examples:**
```zig
// Normalize to NFC
const normalized = try gcode.normalize(alloc, "café", .nfc);
defer alloc.free(normalized);

// Check if already normalized
const is_nfc = gcode.isNormalized("café", .nfc);
```

## Types

### Properties

```zig
pub const Properties = packed struct {
    width: u2,
    grapheme_boundary_class: GraphemeBoundaryClass,
    uppercase: u21,
    lowercase: u21,
    titlecase: u21,
};
```

Complete Unicode properties for a codepoint.

### GraphemeBoundaryClass

```zig
pub const GraphemeBoundaryClass = enum(u4) {
    invalid,
    L, V, T, LV, LVT,
    prepend,
    extend,
    zwj,
    spacing_mark,
    regional_indicator,
    extended_pictographic,
    extended_pictographic_base,
    emoji_modifier,
};
```

Unicode grapheme break property classes.

### GraphemeIterator

```zig
pub const GraphemeIterator = struct {
    pub fn next(self: *GraphemeIterator) ?[]const u8;
};
```

Iterator over grapheme clusters in UTF-8 text.

## Error Handling

gcode functions use Zig's error system:

- `error.InvalidUtf8`: Invalid UTF-8 sequence
- `error.CodepointTooLarge`: Codepoint > 0x10FFFF
- `error.InsufficientSpace`: Buffer too small for encoding

## Memory Management

- **Zero allocation**: All core lookup functions
- **Iterator-based**: Grapheme iteration doesn't allocate
- **Explicit allocation**: Normalization requires allocator
- **No global state**: Thread-safe and async-friendly

## Performance Characteristics

| Operation | Time Complexity | Memory Access |
|-----------|----------------|---------------|
| getWidth | O(1) | 2-3 cache lines |
| getProperties | O(1) | 2-3 cache lines |
| isGraphemeBoundary | O(1) | 1-2 cache lines |
| graphemeIterator | O(n) | Minimal |
| normalize | O(n) | O(n) |

## Thread Safety

All gcode functions are thread-safe and can be used in async contexts without synchronization.</content>
<parameter name="filePath">/data/projects/gcode/docs/api-reference.md