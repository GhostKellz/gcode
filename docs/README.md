# gcode Documentation

Welcome to the gcode documentation! This directory contains comprehensive documentation for the gcode Unicode library.

## Documentation Index

### 📖 User Guides

- **[Terminal Emulator Integration](terminal-emulator-integration.md)** - Complete guide for integrating gcode into terminal emulators
- **[Building and Installation](building.md)** - Installation, building, and deployment guide
- **[Performance Guide](performance.md)** - Performance characteristics and optimization techniques

### 🔧 Reference

- **[API Reference](api-reference.md)** - Complete API documentation with examples

### 🚧 Development

- **[Architecture](architecture.md)** - Internal architecture and design decisions
- **[Contributing](contributing.md)** - Guidelines for contributors
- **[Unicode Data](unicode-data.md)** - Unicode data sources and processing

## Quick Start

If you're new to gcode, start here:

1. **For Terminal Developers**: Read [Terminal Emulator Integration](terminal-emulator-integration.md)
2. **For General Users**: Check the main [README.md](../README.md) in the project root
3. **For API Details**: See [API Reference](api-reference.md)

## Key Concepts

### 3-Level Lookup Tables

gcode uses a revolutionary compressed lookup table system:

```
Codepoint → Stage 1 (256 entries) → Stage 2 (compressed) → Properties
```

This provides O(1) lookups with minimal memory usage.

### Terminal-Optimized

Unlike general Unicode libraries, gcode focuses on terminal-specific operations:

- Character width calculation
- Grapheme cluster boundaries
- East Asian Width support
- Zero-width character handling

### Zero Allocation

Core functions are allocation-free, making gcode suitable for performance-critical terminal code.

## Examples

### Character Width

```zig
const width = gcode.getWidth('한'); // Returns: 2 (double-width)
```

### Grapheme Iteration

```zig
var iter = gcode.graphemeIterator("Hello 🏳️‍🌈 World");
while (iter.next()) |cluster| {
    // Process each grapheme cluster
}
```

### Case Conversion

```zig
const upper = gcode.toUpper('a'); // 'A'
const lower = gcode.toLower('A'); // 'a'
```

## Performance

gcode targets sub-2ns character lookups with <500KB memory usage, making it the fastest Unicode library available.

## Support

- **Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Contributing**: See contribution guidelines

---

**Built for terminals, optimized for speed** ⚡</content>
<parameter name="filePath">/data/projects/gcode/docs/README.md