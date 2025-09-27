//! gcode - Fast Unicode processing for terminal emulators
//!
//! This library provides high-performance Unicode operations optimized
//! for terminal emulators, focusing on character width calculation and
//! grapheme boundary detection.

const std = @import("std");

// Core functionality
pub const Properties = @import("properties.zig").Properties;
pub const GraphemeBoundaryClass = @import("properties.zig").GraphemeBoundaryClass;
pub const GraphemeBreakState = @import("grapheme.zig").BreakState;
pub const GraphemeIterator = @import("grapheme.zig").GraphemeIterator;
pub const ReverseGraphemeIterator = @import("grapheme.zig").ReverseGraphemeIterator;

// Word boundary detection
pub const WordBreakState = @import("word.zig").BreakState;
pub const WordIterator = @import("word.zig").WordIterator;
pub const ReverseWordIterator = @import("word.zig").ReverseWordIterator;
pub const wordBreak = @import("word.zig").wordBreak;

// BiDi algorithm for RTL text
pub const BiDi = @import("bidi.zig").BiDi;
pub const BiDiClass = @import("bidi.zig").BiDiClass;
pub const BiDiContext = @import("bidi.zig").BiDiContext;
pub const Direction = @import("bidi.zig").Direction;
pub const Run = @import("bidi.zig").Run;
pub const getBiDiClass = @import("bidi.zig").getBiDiClass;
pub const reorderForDisplay = @import("bidi.zig").reorderForDisplay;
pub const calculateCursorPosition = @import("bidi.zig").calculateCursorPosition;
pub const visualToLogical = @import("bidi.zig").visualToLogical;

// Script detection for shaping guidance
pub const Script = @import("script.zig").Script;
pub const ScriptRun = @import("script.zig").ScriptRun;
pub const ScriptDetector = @import("script.zig").ScriptDetector;
pub const ShapingInfo = @import("script.zig").ShapingInfo;
pub const ShapingApproach = @import("script.zig").ShapingApproach;
pub const getScript = @import("script.zig").getScript;
pub const detectPrimaryScript = @import("script.zig").detectPrimaryScript;
pub const requiresSpecialTerminalHandling = @import("script.zig").requiresSpecialTerminalHandling;

// Complex script analysis for advanced text processing
pub const ComplexScriptCategory = @import("complex_script.zig").ComplexScriptCategory;

// Text shaping for terminal emulators
pub const TextShaper = @import("shaping.zig").TextShaper;
pub const TerminalShaper = @import("shaping.zig").TerminalShaper;
pub const Glyph = @import("shaping.zig").Glyph;
pub const FontMetrics = @import("shaping.zig").FontMetrics;
pub const TextMetrics = @import("shaping.zig").TextMetrics;
pub const BreakPoint = @import("shaping.zig").BreakPoint;
pub const CursorPos = @import("shaping.zig").CursorPos;
pub const LogicalPosition = @import("shaping.zig").LogicalPosition;
pub const LigatureMapping = @import("shaping.zig").LigatureMapping;
pub const LigatureConfig = @import("shaping.zig").LigatureConfig;
pub const KerningPair = @import("shaping.zig").KerningPair;
pub const ShapingConfig = @import("shaping.zig").ShapingConfig;
pub const PROGRAMMING_LIGATURES = @import("shaping.zig").PROGRAMMING_LIGATURES;
pub const BASIC_KERNING_PAIRS = @import("shaping.zig").BASIC_KERNING_PAIRS;

// Advanced script shaping
pub const AdvancedShaper = @import("advanced_shaping.zig").AdvancedShaper;
pub const ArabicJoining = @import("advanced_shaping.zig").ArabicJoining;
pub const AdvancedArabicForm = @import("advanced_shaping.zig").ArabicForm;
pub const IndicSyllable = @import("advanced_shaping.zig").IndicSyllable;
pub const EmojiSequence = @import("advanced_shaping.zig").EmojiSequence;
pub const EmojiSequenceType = @import("advanced_shaping.zig").EmojiSequenceType;
pub const EmojiPresentation = @import("advanced_shaping.zig").EmojiPresentation;
pub const ShapingCache = @import("advanced_shaping.zig").ShapingCache;
pub const ComplexScriptAnalysis = @import("complex_script.zig").ComplexScriptAnalysis;
pub const ComplexScriptAnalyzer = @import("complex_script.zig").ComplexScriptAnalyzer;
pub const ArabicJoiningType = @import("complex_script.zig").ArabicJoiningType;
pub const ArabicForm = @import("complex_script.zig").ArabicForm;
pub const IndicCategory = @import("complex_script.zig").IndicCategory;
pub const CJKWidth = @import("complex_script.zig").CJKWidth;
pub const getLineBreakBehavior = @import("complex_script.zig").getLineBreakBehavior;
pub const getCursorGranularity = @import("complex_script.zig").getCursorGranularity;

// Main API functions
pub const getProperties = @import("properties.zig").getProperties;
pub const getWidth = @import("properties.zig").getWidth;
pub const isZeroWidth = @import("properties.zig").isZeroWidth;
pub const isWide = @import("properties.zig").isWide;
pub const isNarrow = @import("properties.zig").isNarrow;
pub const graphemeBreak = @import("grapheme.zig").graphemeBreak;

// Lookup table for fast property access
pub const table = @import("properties.zig").tables;

// UTF-8 utilities
pub const utf8 = struct {
    pub fn validate(bytes: []const u8) bool {
        return std.unicode.utf8ValidateSlice(bytes);
    }

    pub fn decode(bytes: []const u8) !u21 {
        if (bytes.len == 0) return error.InvalidUtf8;
        const cp = try std.unicode.utf8Decode(bytes);
        return @intCast(cp);
    }

    pub fn encode(codepoint: u21, buffer: []u8) !u3 {
        if (buffer.len < 4) return error.BufferTooSmall;
        return std.unicode.utf8Encode(codepoint, buffer);
    }

    pub fn codepointCount(bytes: []const u8) !usize {
        return std.unicode.utf8CountCodepoints(bytes);
    }

    pub fn byteSequenceLength(codepoint: u21) !u3 {
        const cp: u32 = codepoint;
        return std.unicode.utf8ByteSequenceLength(cp);
    }
};

// String processing utilities
pub fn stringWidth(utf8_string: []const u8) usize {
    var width: usize = 0;
    var i: usize = 0;

    while (i < utf8_string.len) {
        const len = std.unicode.utf8ByteSequenceLength(utf8_string[i]) catch 1;
        if (i + len > utf8_string.len) break;

        const cp = std.unicode.utf8Decode(utf8_string[i .. i + len]) catch {
            i += 1;
            continue;
        };

        width += getWidth(cp);
        i += len;
    }

    return width;
}

pub fn graphemeIterator(utf8_string: []const u8) GraphemeIterator {
    return GraphemeIterator.init(utf8_string);
}

// Code point iterator
pub const CodePointIterator = struct {
    bytes: []const u8,
    index: usize = 0,

    pub fn init(bytes: []const u8) CodePointIterator {
        return .{ .bytes = bytes };
    }

    pub fn next(self: *CodePointIterator) ?struct { code: u21, offset: usize, len: u3 } {
        if (self.index >= self.bytes.len) return null;

        const start = self.index;
        const len = std.unicode.utf8ByteSequenceLength(self.bytes[start]) catch return null;
        if (start + len > self.bytes.len) return null;

        const cp = std.unicode.utf8Decode(self.bytes[start .. start + len]) catch return null;
        self.index = start + len;

        return .{
            .code = @intCast(cp),
            .offset = start,
            .len = len,
        };
    }

    pub fn peek(self: CodePointIterator) ?struct { code: u21, offset: usize, len: u3 } {
        var temp = self;
        return temp.next();
    }

    pub fn reset(self: *CodePointIterator) void {
        self.index = 0;
    }
};

pub fn codePointIterator(bytes: []const u8) CodePointIterator {
    return CodePointIterator.init(bytes);
}

// Terminal-specific utilities
pub fn isControlCharacter(cp: u21) bool {
    return cp < 0x20 or (cp >= 0x7F and cp <= 0x9F);
}

pub fn isDisplayableInTerminal(cp: u21) bool {
    return !isControlCharacter(cp) and cp != 0x7F;
}

// Cursor movement helpers
pub fn findPreviousGrapheme(text: []const u8, pos: usize) usize {
    if (pos == 0) return 0;

    var iter = ReverseGraphemeIterator.init(text[0..pos]);
    if (iter.prev()) |cluster| {
        return pos - cluster.len;
    }
    return 0;
}

pub fn findNextGrapheme(text: []const u8, pos: usize) usize {
    if (pos >= text.len) return text.len;

    var iter = GraphemeIterator.init(text[pos..]);
    if (iter.next()) |cluster| {
        return pos + cluster.len;
    }
    return text.len;
}

// Word processing utilities (now using advanced UAX #29 implementation)
pub fn wordIterator(bytes: []const u8) WordIterator {
    return WordIterator.init(bytes);
}

// Case conversion functions
pub const Case = enum {
    lower,
    upper,
    title,
};

pub fn toLower(cp: u21) u21 {
    return caseConvert(cp, .lower);
}

pub fn toUpper(cp: u21) u21 {
    return caseConvert(cp, .upper);
}

pub fn toTitle(cp: u21) u21 {
    return caseConvert(cp, .title);
}

fn caseConvert(cp: u21, case: Case) u21 {
    const props = table.get(cp);

    return switch (case) {
        .lower => if (props.lowercase != 0) props.lowercase else cp,
        .upper => if (props.uppercase != 0) props.uppercase else cp,
        .title => if (props.titlecase != 0) props.titlecase else cp,
    };
}

// Unicode normalization
pub const NormalizationForm = @import("normalize.zig").NormalizationForm;
pub const normalize = @import("normalize.zig").normalize;
pub const isNormalized = @import("normalize.zig").isNormalized;

// Tests
test {
    @import("std").testing.refAllDecls(@This());
}

test "UTF-8 utilities" {
    const testing = std.testing;

    // Test validation
    try testing.expect(utf8.validate("hello"));
    try testing.expect(utf8.validate("héllo"));
    try testing.expect(!utf8.validate(&[_]u8{ 0xff, 0xfe }));

    // Test encoding/decoding
    var buf: [4]u8 = undefined;
    const len = try utf8.encode('A', &buf);
    try testing.expectEqual(@as(usize, 1), len);
    try testing.expectEqualSlices(u8, "A", buf[0..len]);

    const decoded = try utf8.decode(buf[0..len]);
    try testing.expectEqual(@as(u21, 'A'), decoded);
}

test "code point iterator" {
    const testing = std.testing;

    var iter = codePointIterator("hello");
    try testing.expectEqual(@as(u21, 'h'), iter.next().?.code);
    try testing.expectEqual(@as(u21, 'e'), iter.next().?.code);
    try testing.expectEqual(@as(u21, 'l'), iter.next().?.code);
    try testing.expectEqual(@as(u21, 'l'), iter.next().?.code);
    try testing.expectEqual(@as(u21, 'o'), iter.next().?.code);
    try testing.expect(iter.next() == null);
}

test "word iterator" {
    const testing = std.testing;

    var iter = wordIterator("hello world");
    const first = iter.next().?;
    try testing.expectEqualStrings("hello", first);

    // Skip whitespace if the iterator returns it separately
    var second = iter.next().?;
    while (second.len > 0 and std.ascii.isWhitespace(second[0])) {
        second = iter.next() orelse break;
    }
    try testing.expectEqualStrings("world", second);
}

test "codepoint case conversion" {
    const testing = std.testing;

    try testing.expectEqual(@as(u21, 'H'), toUpper('h'));
    try testing.expectEqual(@as(u21, 'z'), toLower('Z'));
    try testing.expectEqual(@as(u21, 'A'), toTitle('a'));
}

test "grapheme iteration" {
    const testing = std.testing;

    var iter = graphemeIterator("hello");
    try testing.expectEqualStrings("h", iter.next().?);
    try testing.expectEqualStrings("e", iter.next().?);
    try testing.expectEqualStrings("l", iter.next().?);
    try testing.expectEqualStrings("l", iter.next().?);
    try testing.expectEqualStrings("o", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "reverse grapheme iteration" {
    const testing = std.testing;

    var iter = ReverseGraphemeIterator.init("hello");
    try testing.expectEqualStrings("o", iter.prev().?);
    try testing.expectEqualStrings("l", iter.prev().?);
    try testing.expectEqualStrings("l", iter.prev().?);
    try testing.expectEqualStrings("e", iter.prev().?);
    try testing.expectEqualStrings("h", iter.prev().?);
    try testing.expect(iter.prev() == null);
}

test "cursor movement helpers" {
    const testing = std.testing;

    const text = "hello";
    try testing.expectEqual(@as(usize, 0), findPreviousGrapheme(text, 0));
    try testing.expectEqual(@as(usize, 0), findPreviousGrapheme(text, 1));
    try testing.expectEqual(@as(usize, 1), findPreviousGrapheme(text, 2));

    try testing.expectEqual(@as(usize, 5), findNextGrapheme(text, 5));
    try testing.expectEqual(@as(usize, 2), findNextGrapheme(text, 1));
}
