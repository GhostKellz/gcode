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

/// Script property for text shaping guidance
pub const Script = enum(u8) {
    // Common and inherited - don't require specific shaping
    Common,
    Inherited,

    // Latin-based scripts - simple left-to-right shaping
    Latin,
    Greek,
    Cyrillic,
    Armenian,
    Georgian,

    // RTL scripts requiring BiDi and contextual shaping
    Hebrew,
    Arabic,
    Syriac,
    Thaana,
    Nko,

    // Indic scripts requiring complex shaping
    Devanagari,
    Bengali,
    Gurmukhi,
    Gujarati,
    Oriya,
    Tamil,
    Telugu,
    Kannada,
    Malayalam,
    Sinhala,

    // Southeast Asian scripts
    Thai,
    Lao,
    Myanmar,
    Khmer,

    // CJK scripts
    Han,
    Hiragana,
    Katakana,
    Hangul,
    Bopomofo,

    // Other important scripts
    Tibetan,
    Mongolian,
    Ethiopian,
    Cherokee,
    Canadian_Aboriginal,
    Ogham,
    Runic,
    Braille,

    // Historical and specialized scripts
    Old_Italic,
    Gothic,
    Deseret,
    Shavian,
    Osmanya,
    Cypriot,
    Linear_B,
    Ugaritic,
    Phoenician,
    Kharoshthi,
    Cuneiform,

    // Additional scripts
    Tagalog,
    Hanunoo,
    Buhid,
    Tagbanwa,
    Limbu,
    Tai_Le,
    Buginese,
    Coptic,
    New_Tai_Lue,
    Glagolitic,
    Tifinagh,
    Syloti_Nagri,
    Old_Persian,
    Balinese,
    Phags_Pa,
    Yi,

    // Unknown script
    Unknown,

    /// Returns true if this script requires complex shaping
    pub fn requiresComplexShaping(self: Script) bool {
        return switch (self) {
            // Arabic script family - joining, contextual forms
            .Arabic, .Syriac, .Thaana, .Nko => true,

            // Indic scripts - complex syllable formation
            .Devanagari,
            .Bengali,
            .Gurmukhi,
            .Gujarati,
            .Oriya,
            .Tamil,
            .Telugu,
            .Kannada,
            .Malayalam,
            .Sinhala,
            => true,

            // Southeast Asian scripts - line breaking, positioning
            .Thai, .Lao, .Myanmar, .Khmer => true,

            // Tibetan and Mongolian - stacking, positioning
            .Tibetan, .Mongolian => true,

            else => false,
        };
    }

    /// Returns true if this script is written right-to-left
    pub fn isRTL(self: Script) bool {
        return switch (self) {
            .Hebrew, .Arabic, .Syriac, .Thaana, .Nko => true,
            else => false,
        };
    }

    /// Returns true if this script uses joining behavior (like Arabic)
    pub fn hasJoining(self: Script) bool {
        return switch (self) {
            .Arabic, .Syriac, .Mongolian => true,
            else => false,
        };
    }

    /// Returns true if this script is typically monospace-incompatible
    pub fn isMonospaceChallenge(self: Script) bool {
        return switch (self) {
            // Scripts that don't fit well in monospace
            .Devanagari,
            .Bengali,
            .Thai,
            .Myanmar,
            .Khmer,
            .Tibetan,
            => true,
            else => false,
        };
    }

    /// Returns the typical text direction for this script
    pub fn getTextDirection(self: Script) enum { ltr, rtl, ttb } {
        return switch (self) {
            .Hebrew, .Arabic, .Syriac, .Thaana, .Nko => .rtl,
            .Mongolian => .ttb, // Top-to-bottom (though can be horizontal)
            else => .ltr,
        };
    }

    /// Returns true if this script commonly uses combining marks
    pub fn usesCombiningMarks(self: Script) bool {
        return switch (self) {
            .Latin, .Greek, .Cyrillic => true, // diacritics
            .Hebrew, .Arabic => true, // points, marks
            .Devanagari, .Bengali, .Thai, .Myanmar => true, // vowel marks
            else => false,
        };
    }
};

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

        var runs = std.ArrayList(ScriptRun).init(self.allocator);
        defer runs.deinit();

        var start: usize = 0;
        var current_script = getScript(text[0]);

        for (text[1..], 1..) |cp, i| {
            const script = getScript(cp);

            // Check if we need to start a new run
            if (shouldBreakRun(current_script, script)) {
                // End current run
                try runs.append(ScriptRun{
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
        try runs.append(ScriptRun{
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
    simple,  // Simple left-to-right, character-by-character
    bidi,    // BiDi reordering needed, but simple shaping
    complex, // Full complex script shaping required
};

/// Get script for a codepoint (placeholder - would use lookup table)
pub fn getScript(cp: u32) Script {
    // Simplified script detection for now
    // In the full implementation, this would use generated lookup tables

    // ASCII and Latin-1
    if (cp <= 0x00FF) {
        if (cp <= 0x007F) return .Common; // ASCII
        return .Latin; // Latin-1 supplement
    }

    // Latin Extended
    if (cp >= 0x0100 and cp <= 0x024F) return .Latin;

    // Greek
    if (cp >= 0x0370 and cp <= 0x03FF) return .Greek;

    // Cyrillic
    if (cp >= 0x0400 and cp <= 0x04FF) return .Cyrillic;

    // Hebrew
    if (cp >= 0x0590 and cp <= 0x05FF) return .Hebrew;

    // Arabic
    if (cp >= 0x0600 and cp <= 0x06FF) return .Arabic;
    if (cp >= 0x0750 and cp <= 0x077F) return .Arabic; // Arabic Supplement
    if (cp >= 0x08A0 and cp <= 0x08FF) return .Arabic; // Arabic Extended-A

    // Devanagari
    if (cp >= 0x0900 and cp <= 0x097F) return .Devanagari;

    // Bengali
    if (cp >= 0x0980 and cp <= 0x09FF) return .Bengali;

    // Thai
    if (cp >= 0x0E00 and cp <= 0x0E7F) return .Thai;

    // CJK
    if (cp >= 0x4E00 and cp <= 0x9FFF) return .Han; // CJK Unified Ideographs
    if (cp >= 0x3040 and cp <= 0x309F) return .Hiragana;
    if (cp >= 0x30A0 and cp <= 0x30FF) return .Katakana;
    if (cp >= 0xAC00 and cp <= 0xD7AF) return .Hangul; // Hangul Syllables

    // Emoji and symbols
    if (cp >= 0x1F300 and cp <= 0x1F9FF) return .Common; // Emoji blocks

    return .Unknown;
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

    // Should detect multiple script runs
    try std.testing.expect(runs.len >= 2);
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