# Building and Installation

Complete guide for building, installing, and integrating gcode into your projects.

## Requirements

- **Zig 0.16.0-dev** or later
- **Unicode data files** (downloaded automatically)
- **~500MB disk space** for build artifacts

## Quick Start

```bash
# Clone the repository
git clone https://github.com/ghostkellz/gcode
cd gcode

# Build the library
zig build

# Run tests
zig build test

# Build examples
zig build examples
```

## Installation Methods

### 1. Zig Package Manager (Recommended)

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .gcode = .{
        .url = "https://github.com/ghostkellz/gcode/archive/main.tar.gz",
        .hash = "1220...", // Run zig build to get the actual hash
    },
},
```

Then in your `build.zig`:

```zig
const gcode_dep = b.dependency("gcode", .{});
exe.root_module.addImport("gcode", gcode_dep.module("gcode"));
```

### 2. Git Submodule

```bash
git submodule add https://github.com/ghostkellz/gcode libs/gcode
```

In `build.zig`:

```zig
const gcode_mod = b.addModule("gcode", .{
    .root_source_file = b.path("libs/gcode/src/lib.zig"),
    .imports = &.{
        .{ .name = "unicode_tables", .module = b.createModule(.{ .root_source_file = b.path("libs/gcode/src/unicode_tables.zig") }) },
        .{ .name = "properties", .module = b.createModule(.{ .root_source_file = b.path("libs/gcode/src/properties.zig") }) },
        .{ .name = "lut", .module = b.createModule(.{ .root_source_file = b.path("libs/gcode/src/lut.zig") }) },
        .{ .name = "grapheme", .module = b.createModule(.{ .root_source_file = b.path("libs/gcode/src/grapheme.zig") }) },
    },
});
```

### 3. Manual Copy

Copy the `src/` directory to your project and add the modules manually.

## Build Options

### Debug Build

```bash
zig build
# Creates debug build with assertions and debug info
```

### Release Builds

```bash
# Fast release (recommended for development)
zig build -Doptimize=ReleaseFast

# Safe release (with safety checks)
zig build -Doptimize=ReleaseSafe

# Small release (minimal binary size)
zig build -Doptimize=ReleaseSmall
```

### Custom Targets

```bash
# Cross-compilation
zig build -Dtarget=x86_64-windows

# WebAssembly
zig build -Dtarget=wasm32-freestanding
```

## Build Configuration

### Unicode Data Generation

gcode includes a code generator that creates optimized lookup tables from Unicode data files.

```bash
# Generate Unicode tables (automatic)
zig build

# Force regeneration
zig build --clean && zig build
```

The generator downloads these files automatically:
- `UnicodeData.txt` - Character properties and case mappings
- `EastAsianWidth.txt` - Character width data
- `GraphemeBreakProperty.txt` - Grapheme boundary properties

### Custom Unicode Version

To use a specific Unicode version:

```bash
# Edit src/codegen/generator.zig
const unicode_version = "15.0"; // Change version
```

Then regenerate:

```bash
zig build --clean && zig build
```

## Testing

### Run All Tests

```bash
zig build test
```

### Run Specific Tests

```zig
// In src/lib.zig test blocks
test "character width" {
    try std.testing.expectEqual(@as(u2, 1), gcode.getWidth('A'));
    try std.testing.expectEqual(@as(u2, 2), gcode.getWidth('한'));
}
```

### Unicode Compliance Tests

```bash
# Run Unicode test suite
zig build test -- unicode
```

### Performance Benchmarks

```bash
# Run performance tests
zig build test -- bench
```

## Examples

### Basic Usage

```zig
const std = @import("std");
const gcode = @import("gcode");

pub fn main() !void {
    // Character width
    const width = gcode.getWidth('🚀');
    std.debug.print("Rocket width: {}\n", .{width});

    // Grapheme iteration
    const text = "Hello 🌍!";
    var iter = gcode.graphemeIterator(text);
    while (iter.next()) |cluster| {
        std.debug.print("Grapheme: {s}\n", .{cluster});
    }
}
```

### Terminal Emulator Integration

```zig
const gcode = @import("gcode");

pub const Terminal = struct {
    const Self = @This();

    pub fn renderText(self: *Self, text: []const u8) void {
        var i: usize = 0;
        while (i < text.len) {
            const cp = gcode.utf8.decode(text[i..]) catch break;
            const width = gcode.getWidth(cp);

            self.renderCodepoint(cp, width);
            i += gcode.utf8.codepointLength(cp);
        }
    }

    pub fn moveCursorRight(self: *Self, text: []const u8, pos: usize) usize {
        var iter = gcode.graphemeIterator(text);
        var current_pos: usize = 0;

        while (iter.next()) |cluster| {
            if (current_pos >= pos) {
                return current_pos + cluster.len;
            }
            current_pos += cluster.len;
        }

        return text.len;
    }
};
```

## Troubleshooting

### Build Failures

#### "Unicode data download failed"

```bash
# Check internet connection
curl -I https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt

# Manual download
cd unicode_data
curl -o UnicodeData.txt https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt
```

#### "Hash mismatch"

```bash
# Update build.zig.zon with new hash
zig build
# Copy the hash from the error message
```

#### "Out of memory"

```bash
# Increase RAM or use swap
# Or build on a machine with more memory
export ZIG_OPTIMIZE="ReleaseSmall" # Smaller memory usage
```

### Runtime Issues

#### "Invalid UTF-8"

```zig
// Validate input before processing
if (!gcode.utf8.validate(input)) {
    return error.InvalidUtf8;
}
```

#### "Codepoint out of range"

```zig
// Check codepoint validity
if (cp > 0x10FFFF) {
    return error.InvalidCodepoint;
}
```

### Performance Issues

#### Slow lookups

```zig
// Ensure ReleaseFast optimization
zig build -Doptimize=ReleaseFast

// Profile with
zig build --profile
```

#### High memory usage

```zig
// Check for memory leaks
const tracking = std.heap.trackingAllocator(std.heap.page_allocator);
defer if (tracking.deinit()) {
    std.debug.print("Memory leaks detected!\n", .{});
};
```

## Platform Support

### Supported Platforms

- ✅ **Linux** (x86_64, aarch64)
- ✅ **macOS** (x86_64, aarch64)
- ✅ **Windows** (x86_64)
- ✅ **FreeBSD** (x86_64)
- ✅ **WebAssembly** (wasm32)
- ✅ **Embedded** (no_std)

### Cross-Compilation

```bash
# Linux to Windows
zig build -Dtarget=x86_64-windows

# macOS to Linux
zig build -Dtarget=x86_64-linux

# Any to WebAssembly
zig build -Dtarget=wasm32-freestanding
```

## Contributing

### Development Setup

```bash
# Fork and clone
git clone https://github.com/yourusername/gcode
cd gcode

# Install pre-commit hooks
zig build hooks

# Run tests continuously
zig build test --watch
```

### Code Style

```bash
# Format code
zig fmt src/

# Lint
zig build lint
```

### Adding Tests

```zig
test "new feature" {
    // Test implementation
    try std.testing.expectEqual(expected, actual);
}
```

### Performance Testing

```zig
// In src/performance_tests.zig
test "benchmark" {
    const start = std.time.nanoTimestamp();
    // Benchmark code
    const end = std.time.nanoTimestamp();
    const ns_per_op = (end - start) / iterations;
    std.debug.print("Time: {}ns/op\n", .{ns_per_op});
}
```

## Distribution

### Packaging for Linux

```bash
# Create .deb package
zig build -Dtarget=x86_64-linux --prefix /usr
dpkg-deb --build zig-out /

# Create .rpm package
zig build -Dtarget=x86_64-linux --prefix /usr
rpmbuild -bb gcode.spec
```

### WebAssembly Bundle

```bash
zig build -Dtarget=wasm32-freestanding
# Creates zig-out/bin/gcode.wasm
```

## License

gcode is licensed under the MIT License. See LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/ghostkellz/gcode/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ghostkellz/gcode/discussions)
- **Discord**: [Zig Community](https://discord.gg/zig)

---

Built with ❤️ and Zig ⚡</content>
<parameter name="filePath">/data/projects/gcode/docs/building.md