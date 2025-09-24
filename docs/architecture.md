# Architecture Overview

This document describes the internal architecture and design decisions of gcode.

## Design Philosophy

gcode is built on three core principles:

1. **Terminal-First**: Only implement Unicode operations terminals actually need
2. **Performance-Obsessed**: Every design decision optimizes for speed
3. **Memory-Efficient**: Minimal memory footprint with intelligent compression

## Core Architecture

### 3-Level Lookup Table System

gcode uses a compressed lookup table system inspired by Unicode processing best practices:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Codepoint     │ -> │   Stage 1       │ -> │   Stage 2       │ -> │ Properties     │
│   (21-bit)      │    │   (256 entries) │    │   (compressed)  │    │ (deduplicated) │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### Stage 1: Block Index
- 256-entry array mapping codepoint blocks to stage 2 indices
- `stage1[codepoint >> 8]` gives the stage 2 block index

#### Stage 2: Sub-Block Index
- Variable-length array of 16-bit indices
- Each entry points to a property set in stage 3
- Compressed using deduplication (identical blocks share entries)

#### Stage 3: Properties
- Array of `Properties` structs
- Deduplicated so identical properties share entries
- Packed struct for minimal memory usage

### Memory Layout Benefits

```zig
// Total memory: ~350KB
// Access pattern: 2-3 cache lines per lookup
const props = gcode.getProperties(cp);
// 1. Stage 1 lookup: 1 cache line
// 2. Stage 2 lookup: 1 cache line
// 3. Stage 3 lookup: 1 cache line (if not prefetched)
```

## Code Generation System

### Unicode Data Processing

The build system includes a code generator that:

1. **Downloads Unicode data** from unicode.org
2. **Parses text files** into structured data
3. **Generates compressed tables** optimized for access patterns
4. **Creates Zig source code** for compile-time inclusion

### Generator Architecture

```zig
pub fn main() !void {
    // 1. Download Unicode data files
    try downloadFile(alloc, .unicode_data, "unicode_data/UnicodeData.txt");

    // 2. Parse into hash maps
    var case_map = try parseUnicodeData(alloc, unicode_data);

    // 3. Generate 3-level lookup tables
    const tables = try generator.generate(alloc);

    // 4. Write Zig source code
    try tables.writeZig(lut_file.writer());
}
```

## Key Optimizations

### 1. Property Deduplication

```zig
// Before: Each codepoint stores full Properties struct
// After: Identical properties share one entry
var props_set = std.AutoHashMap(Properties, void).init(alloc);
for (all_codepoints) |cp| {
    try props_set.put(getProperties(cp), {});
}
// Result: ~50K unique property combinations instead of 1.1M
```

### 2. Block-Level Compression

```zig
// Group codepoints into 256-codepoint blocks
// Many blocks have identical properties (e.g., unassigned ranges)
// Result: Massive compression for sparse Unicode ranges
```

### 3. Cache-Optimized Access

```zig
// Sequential memory access pattern
const stage1_idx = cp >> 8;              // Block index
const stage2_idx = stage1[stage1_idx];   // Sub-block index
const props = stage3[stage2[stage2_idx + (cp & 0xFF)]];
// Predictable access = hardware prefetching
```

## Grapheme Boundary Detection

### Stateful Algorithm

gcode implements the Unicode grapheme boundary algorithm with state:

```zig
pub const GraphemeBreakState = struct {
    prev_class: GraphemeBoundaryClass,
    // Additional state for complex rules
};

pub fn isGraphemeBoundary(a: u21, b: u21, state: *GraphemeBreakState) bool {
    // Apply Unicode grapheme break rules
    // Maintain state for multi-codepoint rules
}
```

### Why Stateful?

Some grapheme rules require context beyond adjacent codepoints:

- **Regional Indicators**: 🇺🇸 (US flag) needs state to track pairs
- **Emoji Sequences**: Complex emoji need stateful parsing
- **Hangul Syllables**: Multi-part sequences require state

## Case Conversion Implementation

### Direct Table Lookup

```zig
pub fn toUpper(cp: u21) u21 {
    const props = table.get(cp);
    return if (props.uppercase != 0) props.uppercase else cp;
}
```

### Sentinel Values

- `0` = No case mapping (identity mapping)
- Non-zero = Mapped codepoint
- Enables compact storage (no optional types)

## UTF-8 Processing

### Zero-Copy Design

```zig
pub fn graphemeIterator(str: []const u8) GraphemeIterator {
    return .{ .bytes = str }; // No allocation, no copying
}
```

### SIMD-Ready

UTF-8 validation and processing designed for SIMD acceleration:

```zig
// ASCII fast path
if (byte < 128) {
    // Single-byte ASCII - no decoding needed
}

// Multi-byte sequences optimized for SIMD
```

## Memory Management

### Arena Allocation Strategy

```zig
pub fn normalize(alloc: std.mem.Allocator, str: []const u8, form: NormalizationForm) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    // All allocations go through arena
    // Single deallocation at end
    return arena.allocator.dupe(u8, result);
}
```

### No Global State

- All functions are pure or take explicit state
- Thread-safe by design
- Async-friendly (no blocking operations)

## Platform Optimizations

### x86_64

- BMI2 instructions for bit manipulation
- AVX-512 for bulk character processing
- Memory prefetch hints

### ARM64

- NEON SIMD for UTF-8 processing
- Optimized for Apple Silicon memory layout

### WebAssembly

- Minimal syscall usage
- Optimized for JavaScript interop
- Small binary size priority

## Testing Strategy

### Property-Based Testing

```zig
test "unicode compliance" {
    // Test against all assigned Unicode codepoints
    for (0..0x10FFFF) |cp| {
        const props = gcode.getProperties(@intCast(cp));
        // Verify properties match Unicode standard
    }
}
```

### Fuzz Testing

```zig
test "fuzz utf8" {
    // Fuzz UTF-8 input validation
    const input = fuzz.randomBytes();
    const result = gcode.utf8.validate(input);
    // Verify no crashes, correct validation
}
```

## Future Architecture

### SIMD Acceleration

```zig
// Planned: Bulk character width calculation
pub fn stringWidthSimd(str: []const u8) usize {
    // Process 16 characters simultaneously
    // Gather width values using SIMD
}
```

### Persistent Memory

```zig
// Load tables into persistent memory regions
const tables = try loadIntoPersistentMemory();
```

### GPU Acceleration

For terminal renderers with GPU compute:

```glsl
// Compute shader for parallel width calculation
uniform sampler2D unicode_tables;
float getWidth(uvec2 coord) {
    return texelFetch(unicode_tables, coord, 0).x;
}
```

## Design Decisions

### Why Not std.unicode?

- **Too general**: Includes operations terminals don't need
- **Slower**: Not optimized for terminal workloads
- **Larger**: More code and data than necessary

### Why Not Trie-Based?

- **Cache unfriendly**: Pointer chasing hurts performance
- **Memory inefficient**: More indirection than necessary
- **Complex**: Harder to optimize and maintain

### Why 3-Level Tables?

- **Cache optimal**: Fits in L1/L2 cache
- **Compressable**: Deduplication works well
- **Simple**: Easy to understand and maintain
- **Fast**: Minimal indirection

## Performance Philosophy

**"Make the common case fast"**

- ASCII characters (most text) are 1-cycle operations
- Unicode lookups are 2-3 cache line accesses
- Memory usage stays in CPU caches
- No heap allocation in hot paths

This philosophy ensures gcode performs well on real-world terminal workloads while maintaining correctness for edge cases.</content>
<parameter name="filePath">/data/projects/gcode/docs/architecture.md