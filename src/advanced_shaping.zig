//! Advanced Script Shaping
//!
//! Implements complex script shaping for Arabic, Indic, and other advanced scripts
//! Required for complete terminal Unicode support.

const std = @import("std");
const props = @import("properties.zig");
const bidi = @import("bidi.zig");
const script = @import("script.zig");
const complex_script = @import("complex_script.zig");
const shaping = @import("shaping.zig");
const lib = @import("lib.zig");

/// Arabic joining types from Unicode Standard
pub const ArabicJoining = enum(u3) {
    /// Non-joining character
    U = 0, // Non_Joining

    /// Left-joining character (can join to the left)
    L = 1, // Left_Joining

    /// Right-joining character (can join to the right)
    R = 2, // Right_Joining

    /// Dual-joining character (can join on both sides)
    D = 3, // Dual_Joining

    /// Join causing character (transparent)
    C = 4, // Join_Causing

    /// Transparent character
    T = 5, // Transparent

    pub fn canJoinLeft(self: ArabicJoining) bool {
        return switch (self) {
            .L, .D => true,
            else => false,
        };
    }

    pub fn canJoinRight(self: ArabicJoining) bool {
        return switch (self) {
            .R, .D => true,
            else => false,
        };
    }
};

/// Arabic contextual forms
pub const ArabicForm = enum(u2) {
    isolated = 0,
    initial = 1,
    medial = 2,
    final = 3,
};

/// Basic Arabic joining type lookup (simplified for common characters)
pub const ARABIC_JOINING_TYPES = std.StaticStringMap(ArabicJoining).initComptime(.{
    // Common Arabic letters (Dual-joining)
    .{ "\u{0628}", .D }, // ب (Beh)
    .{ "\u{062A}", .D }, // ت (Teh)
    .{ "\u{062B}", .D }, // ث (Theh)
    .{ "\u{062C}", .D }, // ج (Jeem)
    .{ "\u{062D}", .D }, // ح (Hah)
    .{ "\u{062E}", .D }, // خ (Khah)
    .{ "\u{062F}", .R }, // د (Dal) - Right-joining only
    .{ "\u{0630}", .R }, // ذ (Thal) - Right-joining only
    .{ "\u{0631}", .R }, // ر (Reh) - Right-joining only
    .{ "\u{0632}", .R }, // ز (Zain) - Right-joining only
    .{ "\u{0633}", .D }, // س (Seen)
    .{ "\u{0634}", .D }, // ش (Sheen)
    .{ "\u{0635}", .D }, // ص (Sad)
    .{ "\u{0636}", .D }, // ض (Dad)
    .{ "\u{0637}", .D }, // ط (Tah)
    .{ "\u{0638}", .D }, // ظ (Zah)
    .{ "\u{0639}", .D }, // ع (Ain)
    .{ "\u{063A}", .D }, // غ (Ghain)
    .{ "\u{0641}", .D }, // ف (Feh)
    .{ "\u{0642}", .D }, // ق (Qaf)
    .{ "\u{0643}", .D }, // ك (Kaf)
    .{ "\u{0644}", .D }, // ل (Lam)
    .{ "\u{0645}", .D }, // م (Meem)
    .{ "\u{0646}", .D }, // ن (Noon)
    .{ "\u{0647}", .D }, // ه (Heh)
    .{ "\u{0648}", .R }, // و (Waw) - Right-joining only
    .{ "\u{064A}", .D }, // ي (Yeh)

    // Arabic diacritics (Transparent)
    .{ "\u{064B}", .T }, // Fathatan
    .{ "\u{064C}", .T }, // Dammatan
    .{ "\u{064D}", .T }, // Kasratan
    .{ "\u{064E}", .T }, // Fatha
    .{ "\u{064F}", .T }, // Damma
    .{ "\u{0650}", .T }, // Kasra
    .{ "\u{0651}", .T }, // Shadda
    .{ "\u{0652}", .T }, // Sukun

    // Space and punctuation (Non-joining)
    .{ " ", .U },
    .{ ".", .U },
    .{ ",", .U },
    .{ ":", .U },
    .{ ";", .U },
});

/// Indic syllable structure
pub const IndicSyllable = struct {
    /// Consonant clusters
    consonants: std.ArrayList(u21),

    /// Vowel signs
    vowels: std.ArrayList(u21),

    /// Modifiers and marks
    modifiers: std.ArrayList(u21),

    /// Syllable boundary
    boundary: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .consonants = std.ArrayList(u21).init(allocator),
            .vowels = std.ArrayList(u21).init(allocator),
            .modifiers = std.ArrayList(u21).init(allocator),
            .boundary = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.consonants.deinit();
        self.vowels.deinit();
        self.modifiers.deinit();
    }
};

/// Emoji sequence type
pub const EmojiSequenceType = enum {
    single,           // Single emoji
    skin_tone,        // Emoji + skin tone modifier
    zwj_sequence,     // Zero-width joiner sequence
    tag_sequence,     // Tag sequence (flags, etc.)
    keycap_sequence,  // Keycap sequence
    modifier_sequence, // Modifier sequence
};

/// Emoji presentation type
pub const EmojiPresentation = enum {
    /// Text presentation (monochrome)
    text,

    /// Emoji presentation (color)
    emoji,

    /// Default presentation (depends on context)
    default,
};

/// Emoji sequence information
pub const EmojiSequence = struct {
    /// Type of sequence
    sequence_type: EmojiSequenceType,

    /// Codepoints in the sequence
    codepoints: std.ArrayList(u21),

    /// Display width (usually 1 or 2 for terminals)
    display_width: u8,

    /// Whether this is a color emoji
    is_color: bool,

    /// Color emoji presentation preference
    presentation: EmojiPresentation,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .sequence_type = .single,
            .codepoints = std.ArrayList(u21).init(allocator),
            .display_width = 1,
            .is_color = false,
            .presentation = .default,
        };
    }

    pub fn deinit(self: *Self) void {
        self.codepoints.deinit();
    }
};

/// Performance cache for shaping results
pub const ShapingCache = struct {
    /// Cache entries
    entries: std.HashMap(u64, CacheEntry, std.hash_map.AutoContext(u64), std.hash_map.default_max_load_percentage),

    /// Allocator for cache
    allocator: std.mem.Allocator,

    /// Cache statistics
    hits: u64 = 0,
    misses: u64 = 0,

    const CacheEntry = struct {
        glyphs: []shaping.Glyph,
        timestamp: i64,
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .entries = std.HashMap(u64, CacheEntry, std.hash_map.AutoContext(u64), std.hash_map.default_max_load_percentage).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all cached glyph arrays
        var iterator = self.entries.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.glyphs);
        }
        self.entries.deinit();
    }

    /// Get cache hit rate
    pub fn getHitRate(self: *Self) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }

    /// Generate cache key from text
    fn generateKey(text: []const u8) u64 {
        return std.hash_map.hashString(text);
    }

    /// Look up cached result
    pub fn get(self: *Self, text: []const u8) ?[]shaping.Glyph {
        const key = generateKey(text);
        if (self.entries.get(key)) |entry| {
            self.hits += 1;
            return entry.glyphs;
        }
        self.misses += 1;
        return null;
    }

    /// Store result in cache
    pub fn put(self: *Self, text: []const u8, glyphs: []const shaping.Glyph) !void {
        const key = generateKey(text);
        const cached_glyphs = try self.allocator.dupe(shaping.Glyph, glyphs);

        try self.entries.put(key, CacheEntry{
            .glyphs = cached_glyphs,
            .timestamp = std.time.milliTimestamp(),
        });
    }
};

/// Advanced script shaper
pub const AdvancedShaper = struct {
    allocator: std.mem.Allocator,
    base_shaper: shaping.TextShaper,
    cache: ShapingCache,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .base_shaper = shaping.TextShaper.init(allocator),
            .cache = ShapingCache.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.base_shaper.deinit();
        self.cache.deinit();
    }

    /// Shape text with advanced script support
    pub fn shapeAdvanced(self: *Self, text: []const u8, font_metrics: shaping.FontMetrics) ![]shaping.Glyph {
        // Check cache first
        if (self.cache.get(text)) |cached_glyphs| {
            return try self.allocator.dupe(shaping.Glyph, cached_glyphs);
        }

        // Fast path for ASCII-only text
        if (isAsciiOnly(text)) {
            return self.shapeAsciiOptimized(text, font_metrics);
        }

        // Convert text to codepoints for script detection
        var codepoints = try std.ArrayList(u32).initCapacity(self.allocator, text.len);
        defer codepoints.deinit();

        var iter = lib.codePointIterator(text);
        while (iter.next()) |cp| {
            try codepoints.append(self.allocator, cp.code);
        }

        // Detect script and use appropriate shaping
        const detected_script = script.detectPrimaryScript(codepoints.items);

        const glyphs = switch (detected_script) {
            .Arabic => try self.shapeArabic(text, font_metrics),
            .Devanagari, .Tamil, .Bengali, .Gujarati => try self.shapeIndic(text, font_metrics),
            .Thai, .Lao => try self.shapeThaiLao(text, font_metrics),
            else => try self.base_shaper.shape(text, font_metrics),
        };

        // Enhanced emoji processing
        const processed_glyphs = try self.processEmojiSequences(glyphs);
        defer self.allocator.free(glyphs);

        // Cache the result
        try self.cache.put(text, processed_glyphs);

        return processed_glyphs;
    }

    /// Fast ASCII-only shaping
    fn shapeAsciiOptimized(self: *Self, text: []const u8, font_metrics: shaping.FontMetrics) ![]shaping.Glyph {
        var glyphs = try self.allocator.alloc(shaping.Glyph, text.len);

        for (text, 0..) |char, i| {
            glyphs[i] = shaping.Glyph{
                .id = char,
                .x_advance = font_metrics.cell_width,
                .y_advance = 0,
                .x_offset = 0,
                .y_offset = 0,
                .codepoint = char,
                .byte_offset = i,
                .byte_length = 1,
            };
        }

        return glyphs;
    }

    /// Shape Arabic text with joining
    fn shapeArabic(self: *Self, text: []const u8, font_metrics: shaping.FontMetrics) ![]shaping.Glyph {
        // First get base glyphs
        const base_glyphs = try self.base_shaper.shape(text, font_metrics);
        defer self.allocator.free(base_glyphs);

        // Apply Arabic contextual analysis
        const result_glyphs = try self.allocator.dupe(shaping.Glyph, base_glyphs);

        // Determine contextual forms for each glyph
        for (result_glyphs, 0..) |*glyph, i| {
            const form = self.determineArabicForm(result_glyphs, i);

            // Modify glyph ID based on contextual form
            glyph.id = self.getContextualGlyphId(glyph.codepoint, form);
        }

        return result_glyphs;
    }

    /// Determine Arabic contextual form
    fn determineArabicForm(self: *Self, glyphs: []const shaping.Glyph, index: usize) ArabicForm {
        _ = self;

        if (index >= glyphs.len) return .isolated;

        const current_joining = getArabicJoining(glyphs[index].codepoint);

        // Check if can join to previous character
        var can_join_left = false;
        if (index > 0) {
            const prev_joining = getArabicJoining(glyphs[index - 1].codepoint);
            can_join_left = current_joining.canJoinLeft() and prev_joining.canJoinRight();
        }

        // Check if can join to next character
        var can_join_right = false;
        if (index + 1 < glyphs.len) {
            const next_joining = getArabicJoining(glyphs[index + 1].codepoint);
            can_join_right = current_joining.canJoinRight() and next_joining.canJoinLeft();
        }

        // Determine form based on joining context
        if (can_join_left and can_join_right) {
            return .medial;
        } else if (can_join_left) {
            return .final;
        } else if (can_join_right) {
            return .initial;
        } else {
            return .isolated;
        }
    }

    /// Get contextual glyph ID for Arabic form
    fn getContextualGlyphId(self: *Self, base_codepoint: u21, form: ArabicForm) u32 {
        _ = self;

        // In a real implementation, this would map to actual font glyph IDs
        // For now, we use the base codepoint with form information encoded
        return @as(u32, @intCast(base_codepoint)) | (@as(u32, @intFromEnum(form)) << 24);
    }

    /// Shape Indic scripts (simplified implementation)
    fn shapeIndic(self: *Self, text: []const u8, font_metrics: shaping.FontMetrics) ![]shaping.Glyph {
        // For now, use base shaping with syllable analysis
        const base_glyphs = try self.base_shaper.shape(text, font_metrics);
        defer self.allocator.free(base_glyphs);

        // Analyze syllable structure
        const syllables = try self.analyzeIndicSyllables(text);
        defer {
            for (syllables) |*syllable| {
                syllable.deinit();
            }
            self.allocator.free(syllables);
        }

        // Apply reordering and positioning (simplified)
        const result_glyphs = try self.allocator.dupe(shaping.Glyph, base_glyphs);

        // Apply basic Indic positioning rules
        for (result_glyphs) |*glyph| {
            // Adjust positioning for combining marks
            const properties = props.getProperties(glyph.codepoint);
            if (properties.combining_class > 0) {
                // Combining marks get special positioning
                glyph.x_offset = -font_metrics.cell_width * 0.5;
                glyph.x_advance = 0;
            }
        }

        return result_glyphs;
    }

    /// Analyze Indic syllable structure
    fn analyzeIndicSyllables(self: *Self, text: []const u8) ![]IndicSyllable {
        var syllables = try std.ArrayList(IndicSyllable).initCapacity(self.allocator, 16);
        defer syllables.deinit();

        var current_syllable = IndicSyllable.init(self.allocator);

        var byte_offset: usize = 0;
        while (byte_offset < text.len) {
            const cp_len = std.unicode.utf8ByteSequenceLength(text[byte_offset]) catch 1;
            if (byte_offset + cp_len > text.len) break;

            const codepoint = std.unicode.utf8Decode(text[byte_offset..byte_offset + cp_len]) catch 0;

            // Simplified Indic categorization
            if (isIndicConsonant(codepoint)) {
                try current_syllable.consonants.append(self.allocator, codepoint);
            } else if (isIndicVowel(codepoint)) {
                try current_syllable.vowels.append(self.allocator, codepoint);
            } else {
                // End current syllable and start new one
                if (current_syllable.consonants.items.len > 0 or current_syllable.vowels.items.len > 0) {
                    try syllables.append(self.allocator, current_syllable);
                    current_syllable = IndicSyllable.init(self.allocator);
                }
            }

            byte_offset += cp_len;
        }

        // Add final syllable
        if (current_syllable.consonants.items.len > 0 or current_syllable.vowels.items.len > 0) {
            try syllables.append(self.allocator, current_syllable);
        } else {
            current_syllable.deinit();
        }

        return try self.allocator.dupe(IndicSyllable, syllables.items);
    }

    /// Shape Thai/Lao text with line breaking
    fn shapeThaiLao(self: *Self, text: []const u8, font_metrics: shaping.FontMetrics) ![]shaping.Glyph {
        // Use base shaping for now
        const base_glyphs = try self.base_shaper.shape(text, font_metrics);
        defer self.allocator.free(base_glyphs);

        const result_glyphs = try self.allocator.dupe(shaping.Glyph, base_glyphs);

        // Apply Thai/Lao specific adjustments
        for (result_glyphs) |*glyph| {
            // Thai combining marks positioning
            if (isThaiCombiningMark(glyph.codepoint)) {
                glyph.x_advance = 0;
                glyph.y_offset = -font_metrics.cell_width * 0.3; // Above base
            }
        }

        return result_glyphs;
    }

    /// Process emoji sequences
    fn processEmojiSequences(self: *Self, glyphs: []const shaping.Glyph) ![]shaping.Glyph {
        var result = std.ArrayList(shaping.Glyph).init(self.allocator);
        defer result.deinit();

        var i: usize = 0;
        while (i < glyphs.len) {
            const sequence = try self.detectEmojiSequence(glyphs[i..]);

            if (sequence.codepoints.items.len > 1) {
                // Combine multiple glyphs into one emoji sequence
                var combined_glyph = glyphs[i];
                combined_glyph.x_advance = @as(f32, @floatFromInt(sequence.display_width)) * combined_glyph.x_advance;
                combined_glyph.byte_length = @intCast(sequence.codepoints.items.len);

                try result.append(self.allocator, combined_glyph);
                i += sequence.codepoints.items.len;
            } else {
                // Single glyph
                try result.append(self.allocator, glyphs[i]);
                i += 1;
            }

            sequence.deinit();
        }

        return try self.allocator.dupe(shaping.Glyph, result.items);
    }

    /// Detect emoji sequence starting at given position
    fn detectEmojiSequence(self: *Self, glyphs: []const shaping.Glyph) !EmojiSequence {
        var sequence = EmojiSequence.init(self.allocator);

        if (glyphs.len == 0) return sequence;

        const first_cp = glyphs[0].codepoint;
        try sequence.codepoints.append(self.allocator, first_cp);

        // Check for skin tone modifier
        if (isEmojiBase(first_cp) and glyphs.len > 1 and isSkinToneModifier(glyphs[1].codepoint)) {
            try sequence.codepoints.append(self.allocator, glyphs[1].codepoint);
            sequence.sequence_type = .skin_tone;
            sequence.display_width = 2; // Emoji typically 2 cells wide
            sequence.is_color = true;
            sequence.presentation = .emoji;
            return sequence;
        }

        // Check for ZWJ sequence
        if (isEmojiBase(first_cp) and glyphs.len > 2 and
            glyphs[1].codepoint == 0x200D and // ZWJ
            isEmojiBase(glyphs[2].codepoint)) {
            try sequence.codepoints.append(self.allocator, glyphs[1].codepoint);
            try sequence.codepoints.append(self.allocator, glyphs[2].codepoint);
            sequence.sequence_type = .zwj_sequence;
            sequence.display_width = 2;
            sequence.is_color = true;
            sequence.presentation = .emoji;
            return sequence;
        }

        // Single emoji
        if (isEmojiBase(first_cp)) {
            sequence.sequence_type = .single;
            sequence.display_width = 2;
            sequence.is_color = true;
            sequence.presentation = .emoji;
        }

        return sequence;
    }

    /// Get cache statistics
    pub fn getCacheStats(self: *Self) struct { hit_rate: f64, entries: usize } {
        return .{
            .hit_rate = self.cache.getHitRate(),
            .entries = self.cache.entries.count(),
        };
    }
};

// Helper functions

fn isAsciiOnly(text: []const u8) bool {
    for (text) |byte| {
        if (byte > 127) return false;
    }
    return true;
}

fn getArabicJoining(codepoint: u21) ArabicJoining {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(codepoint, &buf) catch return .U;

    return ARABIC_JOINING_TYPES.get(buf[0..len]) orelse .U;
}

fn isIndicConsonant(codepoint: u21) bool {
    // Simplified: Devanagari consonants range
    return (codepoint >= 0x0915 and codepoint <= 0x0939);
}

fn isIndicVowel(codepoint: u21) bool {
    // Simplified: Devanagari vowel signs range
    return (codepoint >= 0x093E and codepoint <= 0x094F);
}

fn isThaiCombiningMark(codepoint: u21) bool {
    // Thai combining marks
    return (codepoint >= 0x0E30 and codepoint <= 0x0E3A) or
           (codepoint >= 0x0E47 and codepoint <= 0x0E4E);
}

fn isEmojiBase(codepoint: u21) bool {
    // Common emoji ranges
    return (codepoint >= 0x1F600 and codepoint <= 0x1F64F) or // Emoticons
           (codepoint >= 0x1F300 and codepoint <= 0x1F5FF) or // Misc Symbols
           (codepoint >= 0x1F680 and codepoint <= 0x1F6FF) or // Transport
           (codepoint >= 0x1F700 and codepoint <= 0x1F77F) or // Alchemical
           (codepoint >= 0x1F780 and codepoint <= 0x1F7FF) or // Geometric Extended
           (codepoint >= 0x1F800 and codepoint <= 0x1F8FF);   // Supplemental Arrows-C
}

fn isSkinToneModifier(codepoint: u21) bool {
    // Emoji skin tone modifiers
    return (codepoint >= 0x1F3FB and codepoint <= 0x1F3FF);
}

// Tests
test "Arabic joining detection" {
    const testing = std.testing;

    // Test dual-joining character
    const beh_joining = getArabicJoining(0x0628); // ب
    try testing.expect(beh_joining == .D);
    try testing.expect(beh_joining.canJoinLeft());
    try testing.expect(beh_joining.canJoinRight());

    // Test right-joining character
    const dal_joining = getArabicJoining(0x062F); // د
    try testing.expect(dal_joining == .R);
    try testing.expect(!dal_joining.canJoinLeft());
    try testing.expect(dal_joining.canJoinRight());
}

test "emoji sequence detection" {
    const testing = std.testing;

    // Test basic emoji detection
    try testing.expect(isEmojiBase(0x1F600)); // 😀
    try testing.expect(isSkinToneModifier(0x1F3FB)); // Light skin tone
    try testing.expect(!isEmojiBase(0x0041)); // A
}

test "Indic character classification" {
    const testing = std.testing;

    // Test Devanagari characters
    try testing.expect(isIndicConsonant(0x0915)); // क
    try testing.expect(isIndicVowel(0x093E)); // ा
    try testing.expect(!isIndicConsonant(0x0041)); // A
}

test "shaping cache" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var cache = ShapingCache.init(allocator);
    defer cache.deinit();

    // Test cache miss
    try testing.expect(cache.get("test") == null);
    try testing.expect(cache.getHitRate() == 0.0);

    // Add to cache
    const glyphs = [_]shaping.Glyph{.{
        .id = 1,
        .x_advance = 10,
        .y_advance = 0,
        .x_offset = 0,
        .y_offset = 0,
        .codepoint = 'A',
        .byte_offset = 0,
        .byte_length = 1,
    }};

    try cache.put("test", &glyphs);

    // Test cache hit
    const cached = cache.get("test");
    try testing.expect(cached != null);
    try testing.expect(cached.?.len == 1);
    try testing.expect(cache.getHitRate() > 0.0);
}

test "advanced shaper initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var shaper = AdvancedShaper.init(allocator);
    defer shaper.deinit();

    const stats = shaper.getCacheStats();
    try testing.expect(stats.hit_rate == 0.0);
    try testing.expect(stats.entries == 0);
}