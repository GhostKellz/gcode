//! Complex Script Classification and Analysis
//!
//! Provides detailed analysis of complex scripts requiring special text shaping.
//! This module guides zfont on how to handle Arabic, Indic, CJK, and other
//! complex scripts in terminal environments.

const std = @import("std");
const script = @import("script.zig");
const Script = script.Script;

/// Complex script categories based on shaping requirements
pub const ComplexScriptCategory = enum {
    /// Simple scripts requiring no special shaping
    simple,

    /// Arabic-style scripts with joining behavior
    joining,

    /// Indic scripts with syllable formation and combining marks
    indic,

    /// CJK scripts with character width and spacing issues
    cjk,

    /// Southeast Asian scripts with line breaking challenges
    southeast_asian,

    /// Other complex scripts
    other_complex,

    pub fn fromScript(s: Script) ComplexScriptCategory {
        return switch (s) {
            .Arabic, .Syriac, .Mongolian => .joining,

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
            => .indic,

            .Han, .Hiragana, .Katakana, .Hangul, .Bopomofo => .cjk,

            .Thai, .Lao, .Myanmar, .Khmer => .southeast_asian,

            .Tibetan, .Ethiopian => .other_complex,

            else => .simple,
        };
    }
};

/// Arabic joining types for contextual shaping
pub const ArabicJoiningType = enum(u3) {
    U, // Non-joining (Unjoined)
    R, // Right-joining (lam-alif)
    L, // Left-joining
    D, // Dual-joining (most letters)
    C, // Join-causing (tatweel, kashida)
    T, // Transparent (diacritics)

    /// Returns true if this type joins to the left
    pub fn joinsLeft(self: ArabicJoiningType) bool {
        return switch (self) {
            .L, .D => true,
            else => false,
        };
    }

    /// Returns true if this type joins to the right
    pub fn joinsRight(self: ArabicJoiningType) bool {
        return switch (self) {
            .R, .D => true,
            else => false,
        };
    }

    /// Returns true if this is a transparent character
    pub fn isTransparent(self: ArabicJoiningType) bool {
        return self == .T;
    }
};

/// Arabic contextual forms
pub const ArabicForm = enum {
    isolated, // Character standing alone
    initial,  // Character at beginning of word
    medial,   // Character in middle of word
    final,    // Character at end of word
};

/// Indic script categories for syllable formation
pub const IndicCategory = enum(u4) {
    // Consonants
    consonant,
    consonant_dead, // Virama + consonant
    consonant_with_stacker,
    consonant_prefixed,
    consonant_preceding_repha,
    consonant_succeeding_repha,

    // Vowels
    vowel_independent,
    vowel_dependent,

    // Modifiers and marks
    nukta,
    virama,
    tone_mark,
    stress_mark,
    cantillation_mark,

    // Numbers and symbols
    number,
    symbol,

    // Invisible stacker
    invisible_stacker,

    // Other
    other,
};

/// CJK character width classification for terminals
pub const CJKWidth = enum(u2) {
    narrow,    // Half-width (1 terminal cell)
    wide,      // Full-width (2 terminal cells)
    ambiguous, // Context-dependent width
};

/// Complex script analysis result
pub const ComplexScriptAnalysis = struct {
    category: ComplexScriptCategory,
    script: Script,

    // Arabic-specific
    joining_type: ?ArabicJoiningType = null,
    arabic_form: ?ArabicForm = null,

    // Indic-specific
    indic_category: ?IndicCategory = null,
    syllable_position: ?u8 = null,

    // CJK-specific
    cjk_width: ?CJKWidth = null,
    is_ideograph: bool = false,

    // General shaping hints
    requires_context: bool = false,
    can_break_line: bool = true,
    is_mark: bool = false,
    is_cluster_start: bool = true,

    /// Get terminal-specific display width
    pub fn getDisplayWidth(self: ComplexScriptAnalysis) f32 {
        return switch (self.category) {
            .cjk => if (self.cjk_width) |w| switch (w) {
                .narrow => 1.0,
                .wide => 2.0,
                .ambiguous => 1.5, // Let terminal decide
            } else 2.0,
            .indic, .southeast_asian => 1.0, // But may need special positioning
            else => 1.0,
        };
    }

    /// Check if character needs complex shaping
    pub fn needsComplexShaping(self: ComplexScriptAnalysis) bool {
        return switch (self.category) {
            .simple => false,
            else => true,
        };
    }

    /// Get shaping priority (higher = shape first)
    pub fn getShapingPriority(self: ComplexScriptAnalysis) u8 {
        return switch (self.category) {
            .joining => 3, // Arabic joining is critical
            .indic => 2,   // Indic syllables are complex
            .cjk => 1,     // CJK needs width handling
            .southeast_asian => 2, // Line breaking is important
            .other_complex => 1,
            .simple => 0,
        };
    }
};

/// Complex script analyzer
pub const ComplexScriptAnalyzer = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// Analyze a single codepoint for complex script properties
    pub fn analyzeCodepoint(self: Self, cp: u32) ComplexScriptAnalysis {

        const char_script = script.getScript(cp);
        const category = ComplexScriptCategory.fromScript(char_script);

        var analysis = ComplexScriptAnalysis{
            .category = category,
            .script = char_script,
        };

        switch (category) {
            .joining => self.analyzeArabic(cp, &analysis),
            .indic => self.analyzeIndic(cp, &analysis),
            .cjk => self.analyzeCJK(cp, &analysis),
            .southeast_asian => self.analyzeSoutheastAsian(cp, &analysis),
            else => {},
        }

        return analysis;
    }

    /// Analyze text and provide shaping guidance
    pub fn analyzeText(self: Self, text: []const u32) ![]ComplexScriptAnalysis {
        var analyses = try self.allocator.alloc(ComplexScriptAnalysis, text.len);

        for (text, 0..) |cp, i| {
            analyses[i] = self.analyzeCodepoint(cp);
        }

        // Post-process for contextual analysis
        try self.applyContextualAnalysis(text, analyses);

        return analyses;
    }

    /// Arabic script analysis
    fn analyzeArabic(self: Self, cp: u32, analysis: *ComplexScriptAnalysis) void {
        _ = self;

        analysis.joining_type = getArabicJoiningType(cp);
        analysis.requires_context = true;
        analysis.can_break_line = true;

        // Mark diacritics
        if (cp >= 0x064B and cp <= 0x065F) {
            analysis.is_mark = true;
            analysis.is_cluster_start = false;
        }

        // Arabic numerals
        if (cp >= 0x0660 and cp <= 0x0669) {
            analysis.joining_type = .U;
            analysis.requires_context = false;
        }
    }

    /// Indic script analysis
    fn analyzeIndic(self: Self, cp: u32, analysis: *ComplexScriptAnalysis) void {
        _ = self;

        analysis.indic_category = getIndicCategory(cp);
        analysis.requires_context = true;

        // Dependent vowels and marks don't start clusters
        if (analysis.indic_category) |cat| {
            switch (cat) {
                .vowel_dependent,
                .nukta,
                .virama,
                .tone_mark,
                .stress_mark,
                .cantillation_mark,
                => {
                    analysis.is_mark = true;
                    analysis.is_cluster_start = false;
                },
                else => {},
            }
        }
    }

    /// CJK script analysis
    fn analyzeCJK(self: Self, cp: u32, analysis: *ComplexScriptAnalysis) void {
        _ = self;

        analysis.cjk_width = getCJKWidth(cp);
        analysis.is_ideograph = isIdeograph(cp);
        analysis.can_break_line = true; // CJK allows breaks between characters

        // Hiragana and Katakana are typically narrow
        if (analysis.script == .Hiragana or analysis.script == .Katakana) {
            analysis.cjk_width = .narrow;
        }
    }

    /// Southeast Asian script analysis
    fn analyzeSoutheastAsian(self: Self, cp: u32, analysis: *ComplexScriptAnalysis) void {
        _ = self;

        analysis.requires_context = true;

        // Thai and Lao don't use spaces
        if (analysis.script == .Thai or analysis.script == .Lao) {
            analysis.can_break_line = false; // Need dictionary for proper breaks
        }

        // Tone marks and vowels
        if (analysis.script == .Thai) {
            if ((cp >= 0x0E30 and cp <= 0x0E3A) or (cp >= 0x0E47 and cp <= 0x0E4E)) {
                analysis.is_mark = true;
                analysis.is_cluster_start = false;
            }
        }
    }

    /// Apply contextual analysis (Arabic joining, Indic syllables, etc.)
    fn applyContextualAnalysis(
        self: Self,
        text: []const u32,
        analyses: []ComplexScriptAnalysis,
    ) !void {

        // Arabic joining context
        for (analyses, 0..) |*analysis, i| {
            if (analysis.category == .joining) {
                const form = self.calculateArabicForm(text, analyses, i);
                analysis.arabic_form = form;
            }
        }

        // Indic syllable positions
        for (analyses, 0..) |*analysis, i| {
            if (analysis.category == .indic) {
                const position = self.calculateIndicSyllablePosition(text, analyses, i);
                analysis.syllable_position = position;
            }
        }
    }

    /// Calculate Arabic contextual form
    fn calculateArabicForm(
        self: Self,
        text: []const u32,
        analyses: []const ComplexScriptAnalysis,
        index: usize,
    ) ArabicForm {
        _ = self;
        _ = text;

        const current = &analyses[index];
        const joining_type = current.joining_type orelse return .isolated;

        // Check left context
        var can_join_left = false;
        if (index > 0) {
            const prev = &analyses[index - 1];
            if (prev.joining_type) |prev_type| {
                can_join_left = prev_type.joinsRight() and joining_type.joinsLeft();
            }
        }

        // Check right context
        var can_join_right = false;
        if (index < analyses.len - 1) {
            const next = &analyses[index + 1];
            if (next.joining_type) |next_type| {
                can_join_right = joining_type.joinsRight() and next_type.joinsLeft();
            }
        }

        return switch (.{ can_join_left, can_join_right }) {
            .{ true, true } => .medial,
            .{ true, false } => .final,
            .{ false, true } => .initial,
            .{ false, false } => .isolated,
        };
    }

    /// Calculate position within Indic syllable
    fn calculateIndicSyllablePosition(
        self: Self,
        text: []const u32,
        analyses: []const ComplexScriptAnalysis,
        index: usize,
    ) u8 {
        _ = self;
        _ = text;
        _ = analyses;
        _ = index;

        // TODO: Implement Indic syllable analysis
        // This requires complex state machine for different Indic scripts
        return 0;
    }
};

/// Get Arabic joining type for a codepoint
fn getArabicJoiningType(cp: u32) ArabicJoiningType {
    // Simplified classification - in full implementation use lookup table

    // Common Arabic letters
    if (cp >= 0x0627 and cp <= 0x063A) {
        return switch (cp) {
            0x0627, 0x0629, 0x062F, 0x0630, 0x0631, 0x0632, 0x0648, 0x0649 => .R, // Right-joining only
            else => .D, // Dual-joining
        };
    }

    // Arabic diacritics
    if (cp >= 0x064B and cp <= 0x065F) return .T; // Transparent

    // Arabic-Indic digits
    if (cp >= 0x0660 and cp <= 0x0669) return .U; // Non-joining

    return .U; // Default to non-joining
}

/// Get Indic category for a codepoint
fn getIndicCategory(cp: u32) IndicCategory {
    // Simplified classification for Devanagari
    if (cp >= 0x0900 and cp <= 0x097F) {
        if (cp >= 0x0915 and cp <= 0x0939) return .consonant; // Consonants
        if (cp >= 0x093E and cp <= 0x094F) return .vowel_dependent; // Dependent vowels
        if (cp == 0x094D) return .virama; // Virama
        if (cp >= 0x0951 and cp <= 0x0954) return .tone_mark; // Tone marks
    }

    return .other;
}

/// Get CJK width classification
fn getCJKWidth(cp: u32) CJKWidth {
    // Simplified - would use East Asian Width data in full implementation
    if (cp >= 0x4E00 and cp <= 0x9FFF) return .wide; // CJK Unified Ideographs
    if (cp >= 0x3040 and cp <= 0x309F) return .narrow; // Hiragana
    if (cp >= 0x30A0 and cp <= 0x30FF) return .narrow; // Katakana
    if (cp >= 0xAC00 and cp <= 0xD7AF) return .wide; // Hangul Syllables
    if (cp >= 0xFF00 and cp <= 0xFFEF) return .wide; // Fullwidth forms

    return .narrow;
}

/// Check if codepoint is an ideograph
fn isIdeograph(cp: u32) bool {
    return (cp >= 0x4E00 and cp <= 0x9FFF) or // CJK Unified Ideographs
        (cp >= 0x3400 and cp <= 0x4DBF) or // CJK Ext A
        (cp >= 0x20000 and cp <= 0x2A6DF); // CJK Ext B
}

/// Terminal-specific utilities

/// Get recommended line breaking behavior for complex scripts
pub fn getLineBreakBehavior(analysis: ComplexScriptAnalysis) enum {
    always_break,
    never_break,
    dictionary_break,
    contextual_break,
} {
    return switch (analysis.category) {
        .simple => .always_break,
        .joining => .contextual_break, // Don't break Arabic words
        .indic => .never_break,        // Don't break syllables
        .cjk => .always_break,         // Can break between any CJK chars
        .southeast_asian => .dictionary_break, // Need dictionary for Thai/Lao
        .other_complex => .contextual_break,
    };
}

/// Get cursor movement granularity
pub fn getCursorGranularity(analysis: ComplexScriptAnalysis) enum {
    character,
    cluster,
    word,
    syllable,
} {
    return switch (analysis.category) {
        .simple => .character,
        .joining => .character, // Arabic cursor moves by character
        .indic => .cluster,     // Indic cursor moves by grapheme cluster
        .cjk => .character,     // CJK cursor moves by character
        .southeast_asian => .cluster, // Thai/Lao use clusters
        .other_complex => .cluster,
    };
}

test "complex script analysis Arabic" {
    const allocator = std.testing.allocator;

    var analyzer = ComplexScriptAnalyzer.init(allocator);

    // Arabic letter BAA (dual-joining)
    const analysis = analyzer.analyzeCodepoint(0x0628);

    try std.testing.expect(analysis.category == .joining);
    try std.testing.expect(analysis.script == .Arabic);
    try std.testing.expect(analysis.joining_type == .D);
    try std.testing.expect(analysis.requires_context);
}

test "complex script analysis CJK" {
    const allocator = std.testing.allocator;

    var analyzer = ComplexScriptAnalyzer.init(allocator);

    // Chinese ideograph
    const analysis = analyzer.analyzeCodepoint(0x4E00);

    try std.testing.expect(analysis.category == .cjk);
    try std.testing.expect(analysis.script == .Han);
    try std.testing.expect(analysis.is_ideograph);
    try std.testing.expect(analysis.getDisplayWidth() == 2.0);
}

test "complex script text analysis" {
    const allocator = std.testing.allocator;

    var analyzer = ComplexScriptAnalyzer.init(allocator);

    // Mixed Arabic text with joining
    const text = [_]u32{ 0x0628, 0x0627, 0x0628 }; // بَاب (door)

    const analyses = try analyzer.analyzeText(&text);
    defer allocator.free(analyses);

    try std.testing.expect(analyses.len == 3);
    try std.testing.expect(analyses[0].category == .joining);
    try std.testing.expect(analyses[1].category == .joining);
    try std.testing.expect(analyses[2].category == .joining);

    // Check contextual forms
    try std.testing.expect(analyses[0].arabic_form == .initial);
    try std.testing.expect(analyses[1].arabic_form == .medial);
    try std.testing.expect(analyses[2].arabic_form == .final);
}