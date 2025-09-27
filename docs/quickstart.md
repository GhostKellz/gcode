# Quick Start Guide

Get up and running with gcode in minutes!

## Installation

Add gcode to your project:

```bash
zig fetch --save https://github.com/ghostkellz/gcode/archive/refs/head/main.tar.gz
```

Then in your `build.zig`:

```zig
const gcode = b.dependency("gcode", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("gcode", gcode.module("gcode"));
```

## Basic Usage

### 1. Character Properties

```zig
const gcode = @import("gcode");

// Check character width (essential for terminals)
const width = gcode.getWidth('A');     // 1 (normal width)
const wide = gcode.getWidth('中');     // 2 (double width)
const zero = gcode.getWidth('\u{200D}'); // 0 (zero width)

// Character properties
const props = gcode.getProperties('é');
const is_letter = props.general_category == .Ll;
```

### 2. Text Shaping (New!)

Perfect for terminal emulators and code editors:

```zig
var shaper = gcode.TextShaper.init(allocator);
defer shaper.deinit();

const font_metrics = gcode.FontMetrics{
    .units_per_em = 1000,
    .cell_width = 600,
    .line_height = 1200,
    .baseline = 800,
    .size = 12,
};

// Programming ligatures: -> becomes →
const glyphs = try shaper.shape("if x >= y { return true; }", font_metrics);
defer allocator.free(glyphs);

// Each glyph contains position, advance, and ligature info
for (glyphs) |glyph| {
    std.debug.print("Glyph: {} at x={} y={}\n", .{
        glyph.codepoint, glyph.x_offset, glyph.y_offset
    });
}
```

### 3. Advanced Script Support

For international text processing:

```zig
var advanced_shaper = gcode.AdvancedShaper.init(allocator);
defer advanced_shaper.deinit();

// Automatic script detection and proper shaping
const arabic = try advanced_shaper.shapeAdvanced("مرحبا بالعالم", font_metrics);
const hindi = try advanced_shaper.shapeAdvanced("नमस्ते दुनिया", font_metrics);
const emoji = try advanced_shaper.shapeAdvanced("👨‍👩‍👧‍👦", font_metrics);

defer allocator.free(arabic);
defer allocator.free(hindi);
defer allocator.free(emoji);
```

### 4. BiDi Text Processing

```zig
const bidi = gcode.BiDi.init(allocator);
defer bidi.deinit();

const mixed_text = "Hello مرحبا World";
const runs = try bidi.process(mixed_text);
defer allocator.free(runs);

// Get proper visual order for display
const visual_order = try gcode.reorderForDisplay(runs, allocator);
defer allocator.free(visual_order);
```

## Common Patterns

### Terminal Character Width Calculation

```zig
pub fn getDisplayWidth(text: []const u8) usize {
    return gcode.stringWidth(text);
}

pub fn findPrevCursor(text: []const u8, pos: usize) usize {
    return gcode.findPreviousGrapheme(text, pos);
}

pub fn findNextCursor(text: []const u8, pos: usize) usize {
    return gcode.findNextGrapheme(text, pos);
}
```

### Code Editor Ligature Support

```zig
const ShapingConfig = gcode.ShapingConfig{
    .enable_ligatures = true,
    .ligature_config = gcode.LigatureConfig{
        .programming_ligatures = true,
        .contextual_ligatures = false,
    },
    .enable_kerning = true,
    .kerning_strength = 0.8,
    .force_monospace = true, // Essential for code editors
};

var shaper = gcode.TextShaper.initWithConfig(allocator, config);
```

### Performance Monitoring

```zig
const stats = advanced_shaper.getCacheStats();
std.debug.print("Cache hit rate: {d:.1%}\n", .{stats.hit_rate});
std.debug.print("Cache entries: {}\n", .{stats.entries});

// Cache hit rate should be >95% for typical terminal text
```

## Next Steps

- **Terminal Integration**: See [Terminal Emulator Integration](terminal-emulator-integration.md)
- **API Reference**: Complete API documentation in [API Reference](api-reference.md)
- **Performance**: Optimization tips in [Performance Guide](performance.md)

## Performance Targets

gcode achieves:
- **< 50ns per character** for Latin text
- **< 1MB memory** for shaping cache
- **> 95% cache hit rate** for terminal text
- **< 200KB binary** size impact

Perfect for high-performance terminal emulators! 🚀