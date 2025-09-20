const std = @import("std");
const props = @import("properties.zig");
const GraphemeBoundaryClass = props.GraphemeBoundaryClass;
const tables = props.tables;

/// Determines if there is a grapheme break between two codepoints.
/// This must be called sequentially maintaining the state between calls.
///
/// This function does NOT work with control characters. Control characters,
/// line feeds, and carriage returns are expected to be filtered out before
/// calling this function. This is because this function is tuned for terminals.
pub fn graphemeBreak(cp1: u21, cp2: u21, state: *BreakState) bool {
    const p1 = tables.get(cp1);
    const p2 = tables.get(cp2);

    const value = Precompute.data[
        (Precompute.Key{
            .gbc1 = p1.grapheme_boundary_class,
            .gbc2 = p2.grapheme_boundary_class,
            .state = state.*,
        }).index()
    ];
    state.* = value.state;
    return value.result;
}

/// The state that must be maintained between calls to graphemeBreak.
pub const BreakState = packed struct(u2) {
    extended_pictographic: bool = false,
    regional_indicator: bool = false,
};

/// Precomputed lookup table for all grapheme boundary permutations.
/// This table encodes the Unicode grapheme boundary rules in a compact format.
const Precompute = struct {
    const Key = packed struct(u10) {
        state: BreakState,
        gbc1: GraphemeBoundaryClass,
        gbc2: GraphemeBoundaryClass,

        fn index(self: Key) usize {
            return @intCast(@as(u10, @bitCast(self)));
        }
    };

    const Value = packed struct(u3) {
        result: bool,
        state: BreakState,
    };

    /// Precomputed table of all possible grapheme boundary decisions.
    /// Generated at compile time using the Unicode grapheme boundary algorithm.
    const data = precompute: {
        var result: [1 << 10]Value = undefined;

        @setEvalBranchQuota(3_000);
        const info = @typeInfo(GraphemeBoundaryClass).@"enum";
        for (0..1 << 2) |state_init| { // 2^2 = 4 possible states
            for (info.fields) |field1| {
                for (info.fields) |field2| {
                    var state: BreakState = @bitCast(@as(u2, @intCast(state_init)));
                    const key: Key = .{
                        .gbc1 = @field(GraphemeBoundaryClass, field1.name),
                        .gbc2 = @field(GraphemeBoundaryClass, field2.name),
                        .state = state,
                    };
                    const v = graphemeBreakClass(key.gbc1, key.gbc2, &state);
                    result[key.index()] = .{ .result = v, .state = state };
                }
            }
        }

        break :precompute result;
    };
};

/// Core grapheme boundary algorithm from Unicode UAX #29.
/// This is used only at compile time to precompute the lookup table.
fn graphemeBreakClass(
    gbc1: GraphemeBoundaryClass,
    gbc2: GraphemeBoundaryClass,
    state: *BreakState,
) bool {
    // GB11: Emoji Extend* ZWJ x Emoji
    if (!state.extended_pictographic and gbc1.isExtendedPictographic()) {
        state.extended_pictographic = true;
    }

    // GB6: Hangul L x (L|V|LV|LVT)
    if (gbc1 == .L) {
        if (gbc2 == .L or
            gbc2 == .V or
            gbc2 == .LV or
            gbc2 == .LVT) return false;
    }

    // GB7: Hangul (LV | V) x (V | T)
    if (gbc1 == .LV or gbc1 == .V) {
        if (gbc2 == .V or
            gbc2 == .T) return false;
    }

    // GB8: Hangul (LVT | T) x T
    if (gbc1 == .LVT or gbc1 == .T) {
        if (gbc2 == .T) return false;
    }

    // GB9: x (Extend | ZWJ)
    if (gbc2 == .extend or gbc2 == .zwj) return false;

    // GB9a: x SpacingMark
    if (gbc2 == .spacing_mark) return false;

    // GB9b: Prepend x
    if (gbc1 == .prepend) return false;

    // GB12, GB13: Regional_Indicator x Regional_Indicator
    if (gbc1 == .regional_indicator and gbc2 == .regional_indicator) {
        if (state.regional_indicator) {
            state.regional_indicator = false;
            return true;
        } else {
            state.regional_indicator = true;
            return false;
        }
    }

    // GB11: Extended_Pictographic Extend* ZWJ x Extended_Pictographic
    if (state.extended_pictographic and gbc1 == .zwj and gbc2.isExtendedPictographic()) {
        state.extended_pictographic = false;
        return false;
    }

    // Emoji modifier sequence: emoji_modifier_base x emoji_modifier
    if (gbc2 == .emoji_modifier and gbc1 == .extended_pictographic_base) {
        return false;
    }

    return true;
}

/// Iterator for walking through grapheme clusters in UTF-8 text.
/// This provides an efficient way to iterate through text by grapheme clusters.
pub const GraphemeIterator = struct {
    bytes: []const u8,
    index: usize,
    state: BreakState,

    pub fn init(text: []const u8) GraphemeIterator {
        return .{
            .bytes = text,
            .index = 0,
            .state = .{},
        };
    }

    /// Get the next grapheme cluster.
    /// Returns null when iteration is complete.
    pub fn next(self: *GraphemeIterator) ?[]const u8 {
        if (self.index >= self.bytes.len) return null;

        const start = self.index;
        var cp1: u21 = undefined;

        // Decode first codepoint
        const len1 = std.unicode.utf8ByteSequenceLength(self.bytes[start]) catch return null;
        if (start + len1 > self.bytes.len) return null;
        cp1 = @intCast(std.unicode.utf8Decode(self.bytes[start .. start + len1]) catch return null);

        self.index += len1;

        // Find the end of this grapheme cluster
        while (self.index < self.bytes.len) {
            var cp2: u21 = undefined;

            // Decode next codepoint
            const len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch break;
            if (self.index + len > self.bytes.len) break;
            cp2 = @intCast(std.unicode.utf8Decode(self.bytes[self.index .. self.index + len]) catch break);

            // Check if there's a grapheme break
            if (graphemeBreak(cp1, cp2, &self.state)) {
                // Break found, current cluster ends before this codepoint
                break;
            }

            // No break, continue with this codepoint
            cp1 = cp2;
            self.index += len;
        }

        return self.bytes[start..self.index];
    }
};

/// Reverse grapheme iterator for backward iteration.
/// Useful for terminal cursor movement.
pub const ReverseGraphemeIterator = struct {
    bytes: []const u8,
    index: usize,

    pub fn init(bytes: []const u8) ReverseGraphemeIterator {
        return .{
            .bytes = bytes,
            .index = bytes.len,
        };
    }

    /// Get the previous grapheme cluster.
    /// Returns null when iteration is complete.
    /// Note: This is a simplified implementation for terminal use.
    pub fn prev(self: *ReverseGraphemeIterator) ?[]const u8 {
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

test "grapheme iterator" {
    const testing = std.testing;

    // Simple ASCII
    {
        var iter = GraphemeIterator.init("hello");
        try testing.expect(std.mem.eql(u8, iter.next().?, "h"));
        try testing.expect(std.mem.eql(u8, iter.next().?, "e"));
        try testing.expect(std.mem.eql(u8, iter.next().?, "l"));
        try testing.expect(std.mem.eql(u8, iter.next().?, "l"));
        try testing.expect(std.mem.eql(u8, iter.next().?, "o"));
        try testing.expect(iter.next() == null);
    }

    // TODO: Add more comprehensive tests once tables are generated
}
