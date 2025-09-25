//! Word boundary detection for Unicode text
//! Based on Unicode Standard Annex #29

const std = @import("std");
const props = @import("properties.zig");

const WordBreakClass = props.WordBreakClass;
const GraphemeBoundaryClass = props.GraphemeBoundaryClass;
const tables = props.tables;

fn isIgnorable(class: WordBreakClass) bool {
    return switch (class) {
        .extend,
        .format,
        .zwj,
        .ebase,
        .ebase_gaz,
        .emodifier,
        .glue_after_zwj,
        => true,
        else => false,
    };
}

fn isNewline(class: WordBreakClass) bool {
    return class == .cr or class == .lf or class == .newline;
}

fn isAHLetter(class: WordBreakClass) bool {
    return class == .aletter or class == .hebrew_letter;
}

fn isMidLetterOrMidNumLetQ(class: WordBreakClass) bool {
    return class == .midletter or class == .midnumlet or class == .single_quote;
}

fn isMidNumOrMidNumLetQ(class: WordBreakClass) bool {
    return class == .midnum or class == .midnumlet or class == .single_quote;
}

fn isExtendNumLetStarter(class: WordBreakClass) bool {
    return isAHLetter(class) or class == .numeric or class == .katakana or class == .extendnumlet;
}

fn isExtendNumLetFollower(class: WordBreakClass) bool {
    return isAHLetter(class) or class == .numeric or class == .katakana;
}

const PendingMid = enum(u3) {
    none,
    ahletter,
    numeric,
    katakana,
    hebrew_double_quote,
};

/// The state that must be maintained between calls to wordBreak.
pub const BreakState = packed struct(u10) {
    last_class: WordBreakClass = .other,
    pending_mid: PendingMid = .none,
    ri_parity: bool = false,
    initialized: bool = false,

    fn push(self: *BreakState, class: WordBreakClass) void {
        if (isIgnorable(class)) return;

        const prev = self.last_class;
        if (class == .regional_indicator and self.initialized and prev == .regional_indicator) {
            self.ri_parity = !self.ri_parity;
        } else if (class == .regional_indicator) {
            self.ri_parity = true;
        } else {
            self.ri_parity = false;
        }

        self.last_class = class;
        self.initialized = true;
    }
};

fn computeBreak(
    state: *BreakState,
    class1_effective: WordBreakClass,
    class1_raw: WordBreakClass,
    class2: WordBreakClass,
    gbc2: GraphemeBoundaryClass,
) bool {
    // WB3: CR x LF
    if (class1_raw == .cr and class2 == .lf) {
        state.pending_mid = .none;
        return false;
    }

    // WB3a/WB3b: break before and after newline types
    if (isNewline(class1_raw)) {
        state.pending_mid = .none;
        return true;
    }
    if (isNewline(class2)) {
        state.pending_mid = .none;
        return true;
    }

    // WB3c: ZWJ x Extended_Pictographic
    if (class1_raw == .zwj and gbc2.isExtendedPictographic()) {
        return false;
    }

    // WB3d: WSegSpace x WSegSpace
    if (class1_effective == .wsegspace and class2 == .wsegspace) {
        state.pending_mid = .none;
        return false;
    }

    // WB4: ignore extend/format/zwj classes (handled by state management)
    if (isIgnorable(class2)) {
        return false;
    }

    const c1 = class1_effective;
    const c2 = class2;

    // WB5: AHLetter x AHLetter
    if (isAHLetter(c1) and isAHLetter(c2)) {
        state.pending_mid = .none;
        return false;
    }

    // WB6: AHLetter x (MidLetter | MidNumLetQ)
    if (isAHLetter(c1) and isMidLetterOrMidNumLetQ(c2)) {
        state.pending_mid = .ahletter;
        return false;
    }

    // WB7: (MidLetter | MidNumLetQ) x AHLetter following WB6
    if (state.pending_mid == .ahletter and isMidLetterOrMidNumLetQ(c1) and isAHLetter(c2)) {
        state.pending_mid = .none;
        return false;
    }

    // WB7a: Hebrew_Letter x Single_Quote
    if (c1 == .hebrew_letter and c2 == .single_quote) {
        state.pending_mid = .none;
        return false;
    }

    // WB7b: Hebrew_Letter x Double_Quote Hebrew_Letter
    if (c1 == .hebrew_letter and c2 == .double_quote) {
        state.pending_mid = .hebrew_double_quote;
        return false;
    }

    // WB7c: Hebrew_Letter Double_Quote x Hebrew_Letter
    if (state.pending_mid == .hebrew_double_quote and c1 == .double_quote and c2 == .hebrew_letter) {
        state.pending_mid = .none;
        return false;
    }

    // WB8: Numeric x Numeric
    if (c1 == .numeric and c2 == .numeric) {
        state.pending_mid = .none;
        return false;
    }

    // WB9 / WB10: AHLetter <> Numeric
    if ((isAHLetter(c1) and c2 == .numeric) or (c1 == .numeric and isAHLetter(c2))) {
        state.pending_mid = .none;
        return false;
    }

    // WB11 / WB12: numeric sequences with punctuation
    if (c1 == .numeric and isMidNumOrMidNumLetQ(c2)) {
        state.pending_mid = .numeric;
        return false;
    }
    if (state.pending_mid == .numeric and isMidNumOrMidNumLetQ(c1) and c2 == .numeric) {
        state.pending_mid = .none;
        return false;
    }

    // WB13: Katakana x Katakana
    if (c1 == .katakana and c2 == .katakana) {
        state.pending_mid = .none;
        return false;
    }

    // WB13 (mid) handling
    if (c1 == .katakana and isMidNumOrMidNumLetQ(c2)) {
        state.pending_mid = .katakana;
        return false;
    }
    if (state.pending_mid == .katakana and isMidNumOrMidNumLetQ(c1) and c2 == .katakana) {
        state.pending_mid = .none;
        return false;
    }

    // WB13a / WB13b: ExtendNumLet sequences
    if (isExtendNumLetStarter(c1) and c2 == .extendnumlet) {
        state.pending_mid = .none;
        return false;
    }
    if (c1 == .extendnumlet and isExtendNumLetFollower(c2)) {
        state.pending_mid = .none;
        return false;
    }

    // WB15 / WB16: Regional indicator sequences (pairing)
    if (c1 == .regional_indicator and c2 == .regional_indicator and state.ri_parity) {
        state.pending_mid = .none;
        return false;
    }

    // Default: break everywhere else
    state.pending_mid = .none;
    return true;
}

/// Determines if there is a word break between two codepoints.
/// This must be called sequentially maintaining the state between calls.
pub fn wordBreak(cp1: u21, cp2: u21, state: *BreakState) bool {
    const props1 = tables.get(cp1);
    const props2 = tables.get(cp2);

    const class1 = props1.word_break_class;
    const class2 = props2.word_break_class;

    if (!state.initialized) {
        state.push(class1);
    }

    const effective_class1 = if (state.initialized)
        (if (isIgnorable(class1)) state.last_class else class1)
    else if (isIgnorable(class1))
        WordBreakClass.other
    else
        class1;

    const result = computeBreak(state, effective_class1, class1, class2, props2.grapheme_boundary_class);

    state.push(class2);

    if (result and !isIgnorable(class2)) {
        state.pending_mid = .none;
    }

    return result;
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

    // Apostrophes inside words
    {
        var iter = WordIterator.init("can't stop");
        try testing.expect(std.mem.eql(u8, iter.next().?, "can't"));
        try testing.expect(std.mem.eql(u8, iter.next().?, " "));
        try testing.expect(std.mem.eql(u8, iter.next().?, "stop"));
        try testing.expect(iter.next() == null);
    }

    // Numeric sequences with punctuation
    {
        var iter = WordIterator.init("3.1415");
        try testing.expect(std.mem.eql(u8, iter.next().?, "3.1415"));
        try testing.expect(iter.next() == null);
    }

    // Regional indicator flag sequence should remain unbroken
    {
        const flag = "\u{1F1FA}\u{1F1F8}"; // US flag
        var iter = WordIterator.init(flag);
        try testing.expect(std.mem.eql(u8, iter.next().?, flag));
        try testing.expect(iter.next() == null);
    }
}
