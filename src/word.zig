//! Word boundary detection for Unicode text
//! Based on Unicode Standard Annex #29

const std = @import("std");

/// Word break classes for Unicode word boundary detection.
pub const WordBreakClass = enum(u4) {
    other,
    cr,
    lf,
    newline,
    extend,
    regional_indicator,
    format,
    katakana,
    aletter,
    midletter,
    midnum,
    midnumlet,
    numeric,
    extendnumlet,
    zwj,
    wsegspace,
};

const tables = @import("properties.zig").tables;

/// Determines if there is a word break between two codepoints.
/// This must be called sequentially maintaining the state between calls.
pub fn wordBreak(cp1: u21, cp2: u21, state: *BreakState) bool {
    const wbc1 = getWordBreakClass(cp1);
    const wbc2 = getWordBreakClass(cp2);

    const value = Precompute.data[
        (Precompute.Key{
            .wbc1 = wbc1,
            .wbc2 = wbc2,
            .state = state.*,
        }).index()
    ];
    state.* = value.state;
    return value.result;
}

/// The state that must be maintained between calls to wordBreak.
pub const BreakState = packed struct(u3) {
    regional_indicator: bool = false,
    aletter: bool = false,
    numeric: bool = false,
};

/// Precomputed lookup table for all word boundary permutations.
/// This table encodes the Unicode word boundary rules in a compact format.
const Precompute = struct {
    const Key = packed struct(u11) {
        state: BreakState,
        wbc1: WordBreakClass,
        wbc2: WordBreakClass,

        fn index(self: Key) usize {
            return @intCast(@as(u11, @bitCast(self)));
        }
    };

    const Value = packed struct(u4) {
        result: bool,
        state: BreakState,
    };

    /// Precomputed table of all possible word boundary decisions.
    /// Generated at compile time using the Unicode word boundary algorithm.
    const data = precompute: {
        var result: [1 << 11]Value = undefined;

        @setEvalBranchQuota(10_000);
        const info = @typeInfo(WordBreakClass).@"enum";
        for (0..1 << 3) |state_init| { // 2^3 = 8 possible states
            for (info.fields) |field1| {
                for (info.fields) |field2| {
                    var state: BreakState = @bitCast(@as(u3, @intCast(state_init)));
                    const key: Key = .{
                        .wbc1 = @field(WordBreakClass, field1.name),
                        .wbc2 = @field(WordBreakClass, field2.name),
                        .state = state,
                    };
                    const v = wordBreakClass(key.wbc1, key.wbc2, &state);
                    result[key.index()] = .{ .result = v, .state = state };
                }
            }
        }

        break :precompute result;
    };
};

/// Get the word break class for a Unicode codepoint.
/// For now, uses simplified classification - should be replaced with Unicode data.
fn getWordBreakClass(cp: u21) WordBreakClass {
    // Basic classification - should be replaced with Unicode WordBreakProperty.txt data
    if (cp == '\r') return .cr;
    if (cp == '\n') return .lf;
    if (cp >= 'a' and cp <= 'z') return .aletter;
    if (cp >= 'A' and cp <= 'Z') return .aletter;
    if (cp >= '0' and cp <= '9') return .numeric;
    if (cp == ' ' or cp == '\t') return .wsegspace;
    return .other;
}

/// Core word boundary algorithm from Unicode UAX #29.
/// This is used only at compile time to precompute the lookup table.
fn wordBreakClass(
    wbc1: WordBreakClass,
    wbc2: WordBreakClass,
    state: *BreakState,
) bool {
    _ = state; // TODO: Implement full word boundary state machine
    
    // Simplified word boundary rules - should be expanded to full UAX #29
    // For now, just break on different classes
    if (wbc1 != wbc2) return true;
    
    // Don't break within sequences of the same type
    return false;
}

/// Iterator for walking through word boundaries in UTF-8 text.
/// This provides an efficient way to iterate through text by word boundaries.
pub const WordIterator = struct {
    bytes: []const u8,
    index: usize,
    state: BreakState,

    pub fn init(text: []const u8) WordIterator {
        return .{
            .bytes = text,
            .index = 0,
            .state = .{},
        };
    }

    /// Get the next word segment.
    /// Returns null when iteration is complete.
    pub fn next(self: *WordIterator) ?[]const u8 {
        if (self.index >= self.bytes.len) return null;

        const start = self.index;
        var cp1: u21 = undefined;

        // Decode first codepoint
        const len1 = std.unicode.utf8ByteSequenceLength(self.bytes[start]) catch return null;
        if (start + len1 > self.bytes.len) return null;
        cp1 = @intCast(std.unicode.utf8Decode(self.bytes[start .. start + len1]) catch return null);

        self.index += len1;

        // Find the end of this word segment
        while (self.index < self.bytes.len) {
            var cp2: u21 = undefined;

            // Decode next codepoint
            const len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch break;
            if (self.index + len > self.bytes.len) break;
            cp2 = @intCast(std.unicode.utf8Decode(self.bytes[self.index .. self.index + len]) catch break);

            // Check if there's a word break
            if (wordBreak(cp1, cp2, &self.state)) {
                // Break found, current segment ends before this codepoint
                break;
            }

            // No break, continue with this codepoint
            cp1 = cp2;
            self.index += len;
        }

        return self.bytes[start..self.index];
    }
};

/// Reverse word iterator for backward iteration.
/// Useful for terminal cursor movement.
pub const ReverseWordIterator = struct {
    bytes: []const u8,
    index: usize,

    pub fn init(bytes: []const u8) ReverseWordIterator {
        return .{
            .bytes = bytes,
            .index = bytes.len,
        };
    }

    /// Get the previous word segment.
    /// Returns null when iteration is complete.
    /// Note: This is a simplified implementation for terminal use.
    pub fn prev(self: *ReverseWordIterator) ?[]const u8 {
        if (self.index == 0) return null;

        // For terminal use, we can simplify: just go back one codepoint
        // This works for most cases since combining characters are rare in terminals
        const end = self.index;
        var start = end;

        // Find the previous valid UTF-8 sequence
        while (start > 0) {
            start -= 1;
            if (std.unicode.utf8ValidateSlice(self.bytes[start..end])) {
                break;
            }
        }

        self.index = start;
        return self.bytes[start..end];
    }
};

test "word iterator" {
    const testing = std.testing;

    // Simple ASCII
    {
        var iter = WordIterator.init("hello world");
        try testing.expect(std.mem.eql(u8, iter.next().?, "hello"));
        try testing.expect(std.mem.eql(u8, iter.next().?, " "));
        try testing.expect(std.mem.eql(u8, iter.next().?, "world"));
        try testing.expect(iter.next() == null);
    }

    // TODO: Add more comprehensive tests once tables are generated
}
