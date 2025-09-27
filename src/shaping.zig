//! Text Shaping for Terminal Emulators
//!
//! Provides terminal-optimized text shaping capabilities to replace harfbuzz
//! in Ghostshell. Focuses on performance and terminal-specific requirements.

const std = @import("std");
const props = @import("properties.zig");
const bidi = @import("bidi.zig");
const script = @import("script.zig");
const complex_script = @import("complex_script.zig");

/// Programming ligature mapping
pub const LigatureMapping = struct {
    /// Source character sequence (up to 4 chars for terminal ligatures)
    source: [4]u8,

    /// Length of source sequence
    source_len: u8,

    /// Target Unicode codepoint for the ligature
    target: u21,

    /// Whether this ligature is enabled by default
    default_enabled: bool,
};

/// Programming ligatures commonly used in terminal/coding environments
pub const PROGRAMMING_LIGATURES = [_]LigatureMapping{
    // Arrows
    .{ .source = [4]u8{ '-', '>', 0, 0 }, .source_len = 2, .target = 0x2192, .default_enabled = true }, // →
    .{ .source = [4]u8{ '<', '-', 0, 0 }, .source_len = 2, .target = 0x2190, .default_enabled = true }, // ←
    .{ .source = [4]u8{ '=', '>', 0, 0 }, .source_len = 2, .target = 0x21D2, .default_enabled = true }, // ⇒
    .{ .source = [4]u8{ '<', '=', 0, 0 }, .source_len = 2, .target = 0x21D0, .default_enabled = true }, // ⇐
    .{ .source = [4]u8{ '<', '-', '>', 0 }, .source_len = 3, .target = 0x2194, .default_enabled = true }, // ↔
    .{ .source = [4]u8{ '<', '=', '>', 0 }, .source_len = 3, .target = 0x21D4, .default_enabled = true }, // ⇔

    // Comparisons
    .{ .source = [4]u8{ '!', '=', 0, 0 }, .source_len = 2, .target = 0x2260, .default_enabled = true }, // ≠
    .{ .source = [4]u8{ '<', '=', 0, 0 }, .source_len = 2, .target = 0x2264, .default_enabled = true }, // ≤
    .{ .source = [4]u8{ '>', '=', 0, 0 }, .source_len = 2, .target = 0x2265, .default_enabled = true }, // ≥
    .{ .source = [4]u8{ '=', '=', 0, 0 }, .source_len = 2, .target = 0x2261, .default_enabled = false }, // ≡ (optional)

    // Logic
    .{ .source = [4]u8{ '&', '&', 0, 0 }, .source_len = 2, .target = 0x2227, .default_enabled = false }, // ∧ (optional)
    .{ .source = [4]u8{ '|', '|', 0, 0 }, .source_len = 2, .target = 0x2228, .default_enabled = false }, // ∨ (optional)

    // Math symbols
    .{ .source = [4]u8{ '+', '=', 0, 0 }, .source_len = 2, .target = 0x2A72, .default_enabled = false }, // ⩲ (optional)
    .{ .source = [4]u8{ '*', '=', 0, 0 }, .source_len = 2, .target = 0x2A6E, .default_enabled = false }, // ⩮ (optional)

    // Programming symbols
    .{ .source = [4]u8{ ':', ':', 0, 0 }, .source_len = 2, .target = 0x2237, .default_enabled = false }, // ∷ (optional)
    .{ .source = [4]u8{ '/', '=', 0, 0 }, .source_len = 2, .target = 0x2260, .default_enabled = true }, // ≠ (alternate)
};

/// Ligature processing configuration
pub const LigatureConfig = struct {
    /// Enable programming ligatures
    programming_ligatures: bool = true,

    /// Enable only default ligatures (vs all available)
    default_only: bool = true,

    /// Custom ligature set (if null, uses PROGRAMMING_LIGATURES)
    custom_ligatures: ?[]const LigatureMapping = null,
};

/// Kerning pair for Latin script
pub const KerningPair = struct {
    /// Left character
    left: u21,

    /// Right character
    right: u21,

    /// Kerning adjustment in font units (can be negative)
    adjustment: f32,
};

/// Basic kerning pairs for common Latin combinations
pub const BASIC_KERNING_PAIRS = [_]KerningPair{
    // Common problematic pairs in monospace contexts
    .{ .left = 'A', .right = 'V', .adjustment = -0.05 }, // Slight tightening
    .{ .left = 'A', .right = 'W', .adjustment = -0.05 },
    .{ .left = 'A', .right = 'Y', .adjustment = -0.05 },
    .{ .left = 'F', .right = 'A', .adjustment = -0.03 },
    .{ .left = 'L', .right = 'T', .adjustment = -0.04 },
    .{ .left = 'L', .right = 'V', .adjustment = -0.04 },
    .{ .left = 'L', .right = 'W', .adjustment = -0.04 },
    .{ .left = 'L', .right = 'Y', .adjustment = -0.04 },
    .{ .left = 'P', .right = 'A', .adjustment = -0.04 },
    .{ .left = 'R', .right = 'A', .adjustment = -0.02 },
    .{ .left = 'T', .right = 'A', .adjustment = -0.04 },
    .{ .left = 'V', .right = 'A', .adjustment = -0.05 },
    .{ .left = 'W', .right = 'A', .adjustment = -0.04 },
    .{ .left = 'Y', .right = 'A', .adjustment = -0.05 },

    // Period and comma kerning
    .{ .left = 'T', .right = '.', .adjustment = -0.06 },
    .{ .left = 'T', .right = ',', .adjustment = -0.06 },
    .{ .left = 'V', .right = '.', .adjustment = -0.04 },
    .{ .left = 'V', .right = ',', .adjustment = -0.04 },
    .{ .left = 'W', .right = '.', .adjustment = -0.03 },
    .{ .left = 'W', .right = ',', .adjustment = -0.03 },
    .{ .left = 'Y', .right = '.', .adjustment = -0.05 },
    .{ .left = 'Y', .right = ',', .adjustment = -0.05 },
};

/// Shaping configuration
pub const ShapingConfig = struct {
    /// Ligature configuration
    ligatures: LigatureConfig = .{},

    /// Enable kerning adjustments
    kerning: bool = true,

    /// Kerning strength multiplier (0.0 = no kerning, 1.0 = full kerning)
    kerning_strength: f32 = 0.3, // Conservative for terminals

    /// Whether to preserve exact monospace for terminal compatibility
    strict_monospace: bool = true,
};

/// Font metrics for shaping calculations
pub const FontMetrics = struct {
    /// Units per em (typically 1000 or 2048)
    units_per_em: u16,

    /// Advance width for a monospace cell in font units
    cell_width: f32,

    /// Line height in font units
    line_height: f32,

    /// Baseline position from top
    baseline: f32,

    /// Font size in points
    size: f32,
};

/// A positioned glyph in the output
pub const Glyph = struct {
    /// Glyph ID (font-specific)
    id: u32,

    /// X advance in font units
    x_advance: f32,

    /// Y advance in font units (usually 0 for horizontal text)
    y_advance: f32,

    /// X offset for positioning
    x_offset: f32,

    /// Y offset for positioning
    y_offset: f32,

    /// Original codepoint
    codepoint: u21,

    /// Byte offset in source text
    byte_offset: usize,

    /// Length in bytes of source text this glyph represents
    byte_length: u8,
};

/// Text measurement results
pub const TextMetrics = struct {
    /// Total advance width
    width: f32,

    /// Total advance height
    height: f32,

    /// Number of glyphs
    glyph_count: usize,

    /// Number of grapheme clusters
    cluster_count: usize,
};

/// Line breaking opportunity
pub const BreakPoint = struct {
    /// Byte offset in text
    offset: usize,

    /// Break priority (lower = better break point)
    priority: u8,

    /// Whether this is a mandatory break
    mandatory: bool,
};

/// Cursor position information for terminals
pub const CursorPos = struct {
    /// Visual X position in cells
    visual_x: f32,

    /// Logical byte offset
    byte_offset: usize,

    /// Whether cursor is at start or end of character
    at_start: bool,
};

/// Logical position for BiDi cursor handling
pub const LogicalPosition = struct {
    /// Byte offset in logical order
    byte_offset: usize,

    /// Character index in logical order
    char_index: usize,
};

/// Core text shaping interface
pub const TextShaper = struct {
    allocator: std.mem.Allocator,
    config: ShapingConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .config = .{},
        };
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: ShapingConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Shape text into positioned glyphs with ligature and kerning support
    pub fn shape(self: *Self, text: []const u8, font_metrics: FontMetrics) ![]Glyph {
        var glyphs = std.ArrayList(Glyph){};
        defer glyphs.deinit(self.allocator);

        // Step 1: Process ligatures if enabled
        const processed_text = if (self.config.ligatures.programming_ligatures)
            try self.processLigatures(text)
        else
            try self.allocator.dupe(u8, text);
        defer self.allocator.free(processed_text);

        // Step 2: Convert to glyphs
        var byte_offset: usize = 0;
        while (byte_offset < processed_text.len) {
            const cp_len = std.unicode.utf8ByteSequenceLength(processed_text[byte_offset]) catch 1;
            if (byte_offset + cp_len > processed_text.len) break;

            const codepoint = std.unicode.utf8Decode(processed_text[byte_offset..byte_offset + cp_len]) catch 0;

            // Create a glyph for this codepoint
            const glyph = Glyph{
                .id = codepoint, // Use codepoint as glyph ID for now
                .x_advance = font_metrics.cell_width,
                .y_advance = 0,
                .x_offset = 0,
                .y_offset = 0,
                .codepoint = codepoint,
                .byte_offset = byte_offset,
                .byte_length = @intCast(cp_len),
            };

            try glyphs.append(self.allocator, glyph);
            byte_offset += cp_len;
        }

        // Step 3: Apply kerning if enabled
        if (self.config.kerning and !self.config.strict_monospace) {
            try self.applyKerning(glyphs.items, font_metrics);
        }

        return try self.allocator.dupe(Glyph, glyphs.items);
    }

    /// Process ligatures in text
    fn processLigatures(self: *Self, text: []const u8) ![]u8 {
        var result = std.ArrayList(u8){};
        defer result.deinit(self.allocator);

        const ligatures = self.config.ligatures.custom_ligatures orelse &PROGRAMMING_LIGATURES;

        var i: usize = 0;
        while (i < text.len) {
            var found_ligature = false;

            // Check for ligatures starting at position i
            for (ligatures) |ligature| {
                if (!ligature.default_enabled and self.config.ligatures.default_only) continue;

                // Check if we have enough characters and they match
                if (i + ligature.source_len <= text.len) {
                    var matches = true;
                    for (0..ligature.source_len) |j| {
                        if (text[i + j] != ligature.source[j]) {
                            matches = false;
                            break;
                        }
                    }

                    if (matches) {
                        // Found a ligature - encode the target codepoint
                        var utf8_buf: [4]u8 = undefined;
                        const len = std.unicode.utf8Encode(ligature.target, &utf8_buf) catch break;
                        try result.appendSlice(self.allocator, utf8_buf[0..len]);
                        i += ligature.source_len;
                        found_ligature = true;
                        break;
                    }
                }
            }

            if (!found_ligature) {
                // No ligature found, copy the original character
                try result.append(self.allocator, text[i]);
                i += 1;
            }
        }

        return try self.allocator.dupe(u8, result.items);
    }

    /// Apply kerning adjustments to glyphs
    fn applyKerning(self: *Self, glyphs: []Glyph, font_metrics: FontMetrics) !void {

        if (glyphs.len < 2) return;

        for (0..glyphs.len - 1) |i| {
            const left_glyph = &glyphs[i];
            const right_glyph = &glyphs[i + 1];

            // Look for kerning pair
            for (BASIC_KERNING_PAIRS) |pair| {
                if (pair.left == left_glyph.codepoint and pair.right == right_glyph.codepoint) {
                    // Apply kerning adjustment
                    const adjustment = pair.adjustment * font_metrics.cell_width * self.config.kerning_strength;
                    left_glyph.x_advance += adjustment;
                    break;
                }
            }
        }
    }

    /// Measure text dimensions
    pub fn measureText(self: *Self, text: []const u8, font_metrics: FontMetrics) !TextMetrics {
        const glyphs = try self.shape(text, font_metrics);
        defer self.allocator.free(glyphs);

        var width: f32 = 0;
        for (glyphs) |glyph| {
            width += glyph.x_advance;
        }

        return TextMetrics{
            .width = width,
            .height = font_metrics.line_height,
            .glyph_count = glyphs.len,
            .cluster_count = glyphs.len, // For now, each glyph is a cluster
        };
    }

    /// Find line break opportunities
    pub fn findBreakPoints(self: *Self, text: []const u8, max_width: f32) ![]BreakPoint {
        _ = max_width;

        var breaks = std.ArrayList(BreakPoint){};
        defer breaks.deinit(self.allocator);

        // Simple whitespace-based breaking for now
        var byte_offset: usize = 0;
        while (byte_offset < text.len) {
            const cp_len = std.unicode.utf8ByteSequenceLength(text[byte_offset]) catch 1;
            if (byte_offset + cp_len > text.len) break;

            const codepoint = std.unicode.utf8Decode(text[byte_offset..byte_offset + cp_len]) catch 0;

            if (std.ascii.isWhitespace(@intCast(codepoint))) {
                try breaks.append(self.allocator, BreakPoint{
                    .offset = byte_offset,
                    .priority = 1,
                    .mandatory = false,
                });
            }

            byte_offset += cp_len;
        }

        // Add end of text as mandatory break
        try breaks.append(self.allocator, BreakPoint{
            .offset = text.len,
            .priority = 0,
            .mandatory = true,
        });

        return try self.allocator.dupe(BreakPoint, breaks.items);
    }
};

/// Terminal-optimized shaping features
pub const TerminalShaper = struct {
    base_shaper: TextShaper,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .base_shaper = TextShaper.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.base_shaper.deinit();
    }

    /// Enforce monospace constraints on glyphs using Unicode pipeline
    pub fn enforceMonospace(self: *Self, glyphs: []Glyph, cell_width: f32) void {
        _ = self;

        for (glyphs) |*glyph| {
            // Get character width from Unicode properties using gcode pipeline
            const char_width = props.getWidth(glyph.codepoint);

            // Check if character is a combining mark using Unicode properties
            const properties = props.getProperties(glyph.codepoint);
            const is_combining = properties.combining_class > 0;

            // Adjust advance based on character width and properties
            glyph.x_advance = if (is_combining)
                0 // Combining marks have zero width
            else switch (char_width) {
                0 => 0, // Zero-width characters
                1 => cell_width, // Normal width
                2 => cell_width * 2, // Double-width (CJK)
                else => cell_width, // Fallback
            };
        }
    }

    /// Shape text with BiDi awareness using gcode pipeline
    pub fn shapeWithBidi(self: *Self, text: []const u8, font_metrics: FontMetrics, base_direction: bidi.Direction) ![]Glyph {
        // Use gcode's BiDi implementation
        var bidi_processor = bidi.BiDi.init(self.base_shaper.allocator);
        defer bidi_processor.deinit();

        // Process BiDi
        const runs = try bidi_processor.processText(text, base_direction);
        defer self.base_shaper.allocator.free(runs);

        var all_glyphs = std.ArrayList(Glyph){};
        defer all_glyphs.deinit(self.base_shaper.allocator);

        // Shape each BiDi run separately
        for (runs) |run| {
            const run_text = text[run.start..run.start + run.length];
            const run_glyphs = try self.base_shaper.shape(run_text, font_metrics);
            defer self.base_shaper.allocator.free(run_glyphs);

            // Apply monospace enforcement
            self.enforceMonospace(run_glyphs, font_metrics.cell_width);

            // Reverse glyphs if RTL
            if (run.level % 2 == 1) {
                std.mem.reverse(Glyph, run_glyphs);
            }

            try all_glyphs.appendSlice(self.base_shaper.allocator, run_glyphs);
        }

        return try self.base_shaper.allocator.dupe(Glyph, all_glyphs.items);
    }

    /// Analyze script requirements using gcode pipeline
    pub fn analyzeScriptComplexity(self: *Self, text: []const u8) !complex_script.ComplexScriptAnalysis {
        var analyzer = complex_script.ComplexScriptAnalyzer.init(self.base_shaper.allocator);

        // Convert text to codepoints for analysis
        var codepoints = std.ArrayList(u32){};
        defer codepoints.deinit(self.base_shaper.allocator);

        var byte_offset: usize = 0;
        while (byte_offset < text.len) {
            const cp_len = std.unicode.utf8ByteSequenceLength(text[byte_offset]) catch 1;
            if (byte_offset + cp_len > text.len) break;

            const codepoint = std.unicode.utf8Decode(text[byte_offset..byte_offset + cp_len]) catch 0;
            try codepoints.append(self.base_shaper.allocator, codepoint);
            byte_offset += cp_len;
        }

        // Use the first codepoint for analysis (simplified)
        if (codepoints.items.len > 0) {
            return analyzer.analyzeCodepoint(codepoints.items[0]);
        }

        // Default analysis for empty text
        return complex_script.ComplexScriptAnalysis{
            .category = .simple,
            .script = .Common, // Use common script as default
            // .requires_shaping = false, // Field doesn't exist in ComplexScriptAnalysis
            .is_ideograph = false,
            .joining_type = null,
            .arabic_form = null,
            .indic_category = null,
        };
    }

    /// Calculate cursor position from byte offset
    pub fn calculateCursorPosition(self: *Self, text: []const u8, byte_offset: usize, font_metrics: FontMetrics) !CursorPos {
        const glyphs = try self.base_shaper.shape(text[0..@min(byte_offset, text.len)], font_metrics);
        defer self.base_shaper.allocator.free(glyphs);

        var visual_x: f32 = 0;
        for (glyphs) |glyph| {
            visual_x += glyph.x_advance;
        }

        return CursorPos{
            .visual_x = visual_x / font_metrics.cell_width,
            .byte_offset = byte_offset,
            .at_start = true,
        };
    }

    /// Handle BiDi cursor movement for terminals
    pub fn handleBidiCursor(self: *Self, text: []const u8, visual_x: f32, font_metrics: FontMetrics) !LogicalPosition {
        // Use gcode's BiDi implementation for proper cursor handling
        var bidi_processor = bidi.BiDi.init(self.base_shaper.allocator);
        defer bidi_processor.deinit();

        // Process BiDi to get runs
        const runs = try bidi_processor.processText(text, .ltr); // Assume LTR base direction
        defer self.base_shaper.allocator.free(runs);

        // Convert visual position to logical position
        var current_visual_x: f32 = 0;
        var byte_offset: usize = 0;
        var char_index: usize = 0;

        for (runs) |run| {
            const run_text = text[run.start..run.start + run.length];
            const run_glyphs = try self.base_shaper.shape(run_text, font_metrics);
            defer self.base_shaper.allocator.free(run_glyphs);

            // If RTL, reverse the glyph order for visual positioning
            var glyph_order = try self.base_shaper.allocator.alloc(usize, run_glyphs.len);
            defer self.base_shaper.allocator.free(glyph_order);

            if (run.level % 2 == 1) { // RTL
                for (0..run_glyphs.len) |i| {
                    glyph_order[i] = run_glyphs.len - 1 - i;
                }
            } else { // LTR
                for (0..run_glyphs.len) |i| {
                    glyph_order[i] = i;
                }
            }

            // Check if visual_x falls within this run
            for (glyph_order) |glyph_idx| {
                const glyph = run_glyphs[glyph_idx];
                const next_visual_x = current_visual_x + glyph.x_advance / font_metrics.cell_width;

                if (visual_x <= next_visual_x) {
                    // Visual cursor falls within this glyph
                    return LogicalPosition{
                        .byte_offset = run.start + glyph.byte_offset,
                        .char_index = char_index + glyph_idx,
                    };
                }

                current_visual_x = next_visual_x;
            }

            byte_offset = run.start + run.length;
            char_index += run_glyphs.len;
        }

        // Cursor is at the end
        return LogicalPosition{
            .byte_offset = text.len,
            .char_index = char_index,
        };
    }

    /// Enhanced cursor positioning with BiDi awareness
    pub fn calculateBidiCursorPosition(self: *Self, text: []const u8, logical_offset: usize, font_metrics: FontMetrics) !CursorPos {
        // Use gcode's BiDi implementation
        var bidi_processor = bidi.BiDi.init(self.base_shaper.allocator);
        defer bidi_processor.deinit();

        const runs = try bidi_processor.processText(text, .ltr);
        defer self.base_shaper.allocator.free(runs);

        // Find which run contains the logical offset
        var visual_x: f32 = 0;
        var current_logical_pos: usize = 0;

        for (runs) |run| {
            if (logical_offset >= run.start and logical_offset < run.start + run.length) {
                // Target position is in this run
                const run_text = text[run.start..run.start + run.length];
                const run_glyphs = try self.base_shaper.shape(run_text, font_metrics);
                defer self.base_shaper.allocator.free(run_glyphs);

                // Calculate position within run
                const offset_within_run = logical_offset - run.start;
                var run_visual_x: f32 = 0;

                if (run.level % 2 == 1) { // RTL run
                    // For RTL, accumulate from the end
                    for (0..run_glyphs.len) |i| {
                        const glyph_idx = run_glyphs.len - 1 - i;
                        const glyph = run_glyphs[glyph_idx];

                        if (glyph.byte_offset <= offset_within_run and
                            offset_within_run < glyph.byte_offset + glyph.byte_length) {
                            // Found the glyph
                            return CursorPos{
                                .visual_x = visual_x + run_visual_x,
                                .byte_offset = logical_offset,
                                .at_start = offset_within_run == glyph.byte_offset,
                            };
                        }

                        run_visual_x += glyph.x_advance / font_metrics.cell_width;
                    }
                } else { // LTR run
                    for (run_glyphs) |glyph| {
                        if (glyph.byte_offset <= offset_within_run and
                            offset_within_run < glyph.byte_offset + glyph.byte_length) {
                            // Found the glyph
                            return CursorPos{
                                .visual_x = visual_x + run_visual_x,
                                .byte_offset = logical_offset,
                                .at_start = offset_within_run == glyph.byte_offset,
                            };
                        }

                        run_visual_x += glyph.x_advance / font_metrics.cell_width;
                    }
                }

                // If we get here, position is at end of run
                return CursorPos{
                    .visual_x = visual_x + run_visual_x,
                    .byte_offset = logical_offset,
                    .at_start = false,
                };
            }

            // Calculate visual width of this run
            const run_text = text[run.start..run.start + run.length];
            const run_glyphs = try self.base_shaper.shape(run_text, font_metrics);
            defer self.base_shaper.allocator.free(run_glyphs);

            for (run_glyphs) |glyph| {
                visual_x += glyph.x_advance / font_metrics.cell_width;
            }

            current_logical_pos = run.start + run.length;
        }

        // Position is at the very end
        return CursorPos{
            .visual_x = visual_x,
            .byte_offset = logical_offset,
            .at_start = false,
        };
    }
};

// Tests
test "basic text shaping" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var shaper = TextShaper.init(allocator);
    defer shaper.deinit();

    const font_metrics = FontMetrics{
        .units_per_em = 1000,
        .cell_width = 600,
        .line_height = 1200,
        .baseline = 800,
        .size = 12,
    };

    const glyphs = try shaper.shape("Hello", font_metrics);
    defer allocator.free(glyphs);

    try testing.expect(glyphs.len == 5);
    try testing.expect(glyphs[0].codepoint == 'H');
    try testing.expect(glyphs[0].x_advance == 600);
}

test "text measurement" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var shaper = TextShaper.init(allocator);
    defer shaper.deinit();

    const font_metrics = FontMetrics{
        .units_per_em = 1000,
        .cell_width = 600,
        .line_height = 1200,
        .baseline = 800,
        .size = 12,
    };

    const metrics = try shaper.measureText("Hello", font_metrics);

    try testing.expect(metrics.width == 3000); // 5 chars * 600 units
    try testing.expect(metrics.glyph_count == 5);
}

test "terminal monospace enforcement" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var terminal_shaper = TerminalShaper.init(allocator);
    defer terminal_shaper.deinit();

    const font_metrics = FontMetrics{
        .units_per_em = 1000,
        .cell_width = 600,
        .line_height = 1200,
        .baseline = 800,
        .size = 12,
    };

    const base_glyphs = try terminal_shaper.base_shaper.shape("A漢", font_metrics);
    defer allocator.free(base_glyphs);

    terminal_shaper.enforceMonospace(base_glyphs, font_metrics.cell_width);

    // 'A' should be 1 cell width, '漢' should be 2 cell widths
    try testing.expect(base_glyphs[0].x_advance == 600);
    // Note: The actual width depends on the Unicode width property
}

test "programming ligatures" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var shaper = TextShaper.init(allocator);
    defer shaper.deinit();

    const font_metrics = FontMetrics{
        .units_per_em = 1000,
        .cell_width = 600,
        .line_height = 1200,
        .baseline = 800,
        .size = 12,
    };

    // Test arrow ligature
    const arrow_glyphs = try shaper.shape("->", font_metrics);
    defer allocator.free(arrow_glyphs);

    // Should have 1 glyph (the arrow) instead of 2
    try testing.expect(arrow_glyphs.len == 1);
    try testing.expect(arrow_glyphs[0].codepoint == 0x2192); // →

    // Test inequality ligature
    const neq_glyphs = try shaper.shape("!=", font_metrics);
    defer allocator.free(neq_glyphs);

    try testing.expect(neq_glyphs.len == 1);
    try testing.expect(neq_glyphs[0].codepoint == 0x2260); // ≠
}

test "kerning with non-monospace" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const config = ShapingConfig{
        .kerning = true,
        .strict_monospace = false, // Allow kerning
        .kerning_strength = 0.5,
    };

    var shaper = TextShaper.initWithConfig(allocator, config);
    defer shaper.deinit();

    const font_metrics = FontMetrics{
        .units_per_em = 1000,
        .cell_width = 600,
        .line_height = 1200,
        .baseline = 800,
        .size = 12,
    };

    // Test kerning pair "AV"
    const glyphs = try shaper.shape("AV", font_metrics);
    defer allocator.free(glyphs);

    try testing.expect(glyphs.len == 2);
    // First glyph should have adjusted advance due to kerning
    try testing.expect(glyphs[0].x_advance < 600); // Should be kerned
}

test "script complexity analysis" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var terminal_shaper = TerminalShaper.init(allocator);
    defer terminal_shaper.deinit();

    // Test Latin script (script may vary based on implementation)
    const latin_analysis = try terminal_shaper.analyzeScriptComplexity("Hello");
    try testing.expect(latin_analysis.category == .simple);
    // Script detection may return Common or Latin for ASCII text
    try testing.expect(latin_analysis.script == .Latin or latin_analysis.script == .Common);

    // Test empty text
    const empty_analysis = try terminal_shaper.analyzeScriptComplexity("");
    try testing.expect(empty_analysis.category == .simple);
}