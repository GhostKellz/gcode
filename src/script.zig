//! Script Detection for Unicode Text
//!
//! Implements script detection to guide zfont's text shaping decisions.
//! Critical for proper rendering of complex scripts like Arabic, Indic, CJK, etc.
//!
//! This module provides the semantic layer that tells zfont:
//! - What script each character belongs to
//! - How to group characters for shaping
//! - Which shaping rules to apply

const std = @import("std");
const properties = @import("properties.zig");

/// Script property for text shaping guidance.
/// Canonical definition (full UCD 16.0.0 value set) lives in `properties.zig`;
/// re-exported here so the public API surface stays stable.
pub const Script = properties.Script;

/// Script run - a sequence of characters from the same script
pub const ScriptRun = struct {
    script: Script,
    start: usize,
    length: usize,

    pub fn end(self: ScriptRun) usize {
        return self.start + self.length;
    }
};

/// Script detection context
pub const ScriptDetector = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// Detect script runs in text
    pub fn detectRuns(self: Self, text: []const u32) ![]ScriptRun {
        if (text.len == 0) {
            return try self.allocator.dupe(ScriptRun, &[_]ScriptRun{});
        }

        var runs: std.ArrayList(ScriptRun) = .empty;
        defer runs.deinit(self.allocator);

        var start: usize = 0;
        var current_script = getScript(text[0]);

        for (text[1..], 1..) |cp, i| {
            const script = getScript(cp);

            // Check if we need to start a new run
            if (shouldBreakRun(current_script, script)) {
                // End current run
                try runs.append(self.allocator, ScriptRun{
                    .script = current_script,
                    .start = start,
                    .length = i - start,
                });

                start = i;
                current_script = script;
            } else if (current_script == .Common or current_script == .Inherited) {
                // Inherit script from following character if current is Common/Inherited
                current_script = script;
            }
        }

        // Add final run
        try runs.append(self.allocator, ScriptRun{
            .script = current_script,
            .start = start,
            .length = text.len - start,
        });

        return try self.allocator.dupe(ScriptRun, runs.items);
    }

    /// Analyze text and return shaping guidance
    pub fn analyzeForShaping(self: Self, text: []const u32) !ShapingInfo {
        const runs = try self.detectRuns(text);
        defer self.allocator.free(runs);

        var info = ShapingInfo{
            .allocator = self.allocator,
            .requires_bidi = false,
            .requires_complex_shaping = false,
            .has_rtl_content = false,
            .dominant_script = .Latin,
        };

        var script_counts = std.AutoHashMap(Script, usize).init(self.allocator);
        defer script_counts.deinit();

        for (runs) |run| {
            const script = run.script;

            // Update flags
            if (script.isRTL()) {
                info.requires_bidi = true;
                info.has_rtl_content = true;
            }

            if (script.requiresComplexShaping()) {
                info.requires_complex_shaping = true;
            }

            // Count script usage
            const count = script_counts.get(script) orelse 0;
            try script_counts.put(script, count + run.length);
        }

        // Find dominant script
        var max_count: usize = 0;
        var it = script_counts.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* > max_count) {
                max_count = entry.value_ptr.*;
                info.dominant_script = entry.key_ptr.*;
            }
        }

        return info;
    }
};

/// Information about text shaping requirements
pub const ShapingInfo = struct {
    allocator: std.mem.Allocator,
    requires_bidi: bool,
    requires_complex_shaping: bool,
    has_rtl_content: bool,
    dominant_script: Script,

    /// Get recommended shaping approach
    pub fn getShapingApproach(self: ShapingInfo) ShapingApproach {
        if (self.requires_complex_shaping) {
            return .complex;
        } else if (self.requires_bidi) {
            return .bidi;
        } else {
            return .simple;
        }
    }
};

/// Shaping approach recommendation for zfont
pub const ShapingApproach = enum {
    simple, // Simple left-to-right, character-by-character
    bidi, // BiDi reordering needed, but simple shaping
    complex, // Full complex script shaping required
};

/// Get the Unicode script (UAX #24) for a codepoint via the generated tables.
pub fn getScript(cp: u32) Script {
    if (cp > 0x10FFFF) return .Unknown;
    return properties.tables.get(@intCast(cp)).script;
}

/// Determine if we should break a script run between two scripts
fn shouldBreakRun(current: Script, next: Script) bool {
    // Never break on Common or Inherited
    if (next == .Common or next == .Inherited) return false;
    if (current == .Common or current == .Inherited) return false;

    // Break if scripts are different
    return current != next;
}

/// Detect the primary script in mixed-script text
pub fn detectPrimaryScript(text: []const u32) Script {
    var script_counts = std.AutoHashMap(Script, usize).init(std.heap.page_allocator);
    defer script_counts.deinit();

    for (text) |cp| {
        const script = getScript(cp);
        if (script == .Common or script == .Inherited) continue;

        const count = script_counts.get(script) orelse 0;
        script_counts.put(script, count + 1) catch continue;
    }

    var max_count: usize = 0;
    var primary_script: Script = .Latin;

    var it = script_counts.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            primary_script = entry.key_ptr.*;
        }
    }

    return primary_script;
}

/// Terminal-specific script utilities
/// Check if text requires special terminal handling
pub fn requiresSpecialTerminalHandling(script: Script) bool {
    return switch (script) {
        // Scripts that need careful terminal positioning
        .Arabic, .Hebrew => true, // RTL + joining
        .Devanagari, .Bengali => true, // Complex combining marks
        .Thai, .Myanmar => true, // Line breaking challenges
        .Han, .Hiragana, .Katakana => true, // Width variations
        else => false,
    };
}

/// Get recommended terminal cell width for script
pub fn getRecommendedCellWidth(script: Script) f32 {
    return switch (script) {
        .Han, .Hiragana, .Katakana, .Hangul => 2.0, // CJK - typically wide
        .Thai, .Myanmar, .Khmer => 1.0, // Southeast Asian - narrow but complex
        else => 1.0, // Most scripts fit in single cell
    };
}

test "script detection basic" {
    const allocator = std.testing.allocator;

    const text = [_]u32{ 'H', 'e', 'l', 'l', 'o' };

    var detector = ScriptDetector.init(allocator);
    const runs = try detector.detectRuns(&text);
    defer allocator.free(runs);

    try std.testing.expect(runs.len == 1);
    try std.testing.expect(runs[0].script == .Common or runs[0].script == .Latin);
    try std.testing.expect(runs[0].start == 0);
    try std.testing.expect(runs[0].length == 5);
}

test "script detection mixed" {
    const allocator = std.testing.allocator;

    // Mixed English and Hebrew
    const text = [_]u32{ 'H', 'e', 'l', 'l', 'o', ' ', 0x05D0, 0x05D1, 0x05D2 };

    var detector = ScriptDetector.init(allocator);
    const runs = try detector.detectRuns(&text);
    defer allocator.free(runs);

    // Should detect at least one script run (Arabic)
    try std.testing.expect(runs.len >= 1);
}

test "getScript table-backed classification" {
    try std.testing.expectEqual(Script.Latin, getScript('A'));
    try std.testing.expectEqual(Script.Latin, getScript('z'));
    try std.testing.expectEqual(Script.Greek, getScript(0x03B1)); // α
    try std.testing.expectEqual(Script.Cyrillic, getScript(0x0434)); // д
    try std.testing.expectEqual(Script.Han, getScript(0x4E2D)); // 中
    try std.testing.expectEqual(Script.Hebrew, getScript(0x05D0)); // א
    try std.testing.expectEqual(Script.Arabic, getScript(0x0627)); // ا
    try std.testing.expectEqual(Script.Devanagari, getScript(0x0905)); // अ
    try std.testing.expectEqual(Script.Hiragana, getScript(0x3042)); // あ
    try std.testing.expectEqual(Script.Common, getScript('5')); // digits are Common
    try std.testing.expectEqual(Script.Unknown, getScript(0x10FFFF + 1)); // out of range
}

test "script shaping analysis" {
    const allocator = std.testing.allocator;

    // Arabic text (requires complex shaping)
    const text = [_]u32{ 0x0627, 0x0644, 0x0639, 0x0631, 0x0628, 0x064A, 0x0629 };

    var detector = ScriptDetector.init(allocator);
    const info = try detector.analyzeForShaping(&text);

    try std.testing.expect(info.requires_bidi);
    try std.testing.expect(info.requires_complex_shaping);
    try std.testing.expect(info.has_rtl_content);
    try std.testing.expect(info.dominant_script == .Arabic);
    try std.testing.expect(info.getShapingApproach() == .complex);
}
