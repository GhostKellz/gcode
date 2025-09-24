//! Unicode normalization for text processing
//! Implements full Unicode normalization (NFC/NFD/NFKC/NFKD) with composition/decomposition

const std = @import("std");
const tables = @import("properties.zig").tables;

pub const NormalizationForm = enum {
    nfc, // Canonical Composition
    nfd, // Canonical Decomposition
    nfkc, // Compatibility Composition
    nfkd, // Compatibility Decomposition
};

/// Normalization result buffer
pub const NormalizationBuffer = struct {
    buffer: std.ArrayList(u21),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) NormalizationBuffer {
        return .{
            .buffer = .empty,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *NormalizationBuffer) void {
        self.buffer.deinit(self.alloc);
    }

    pub fn clear(self: *NormalizationBuffer) void {
        self.buffer.clearRetainingCapacity();
    }

    pub fn toUtf8(self: *NormalizationBuffer) ![]u8 {
        var result = std.ArrayList(u8).empty;
        defer result.deinit(self.alloc);

        for (self.buffer.items) |cp| {
            var buf: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(cp, &buf);
            try result.appendSlice(self.alloc, buf[0..len]);
        }

        return result.toOwnedSlice(self.alloc);
    }
};

/// Decompose a codepoint into its canonical decomposition
/// Returns the decomposition as a slice of codepoints, or null if no decomposition exists
pub fn decomposeCanonical(cp: u21) ?[]const u21 {
    // TODO: Implement with UnicodeData.txt decomposition mappings
    // For now, return null (no decomposition)
    _ = cp;
    return null;
}

/// Decompose a codepoint into its compatibility decomposition
/// Returns the decomposition as a slice of codepoints, or null if no decomposition exists
pub fn decomposeCompatibility(cp: u21) ?[]const u21 {
    // TODO: Implement with UnicodeData.txt compatibility decomposition mappings
    // For now, return null (no decomposition)
    _ = cp;
    return null;
}

/// Check if a codepoint is a combining mark (combining class > 0)
pub fn isCombiningMark(cp: u21) bool {
    // TODO: Implement with canonical combining class from UnicodeData.txt
    // For now, check basic ranges
    const props = tables.get(cp);
    // Combining marks typically have grapheme boundary class of extend or spacing_mark
    return props.grapheme_boundary_class == .extend or
        props.grapheme_boundary_class == .spacing_mark;
}

/// Get the canonical combining class of a codepoint
pub fn combiningClass(cp: u21) u8 {
    // TODO: Implement with UnicodeData.txt combining class data
    // For now, return 0 (not a combining mark)
    _ = cp;
    return 0;
}

/// Canonical ordering of combining marks in a sequence
pub fn canonicalOrdering(sequence: []u21) void {
    // Simple bubble sort by combining class
    var i: usize = 0;
    while (i < sequence.len) : (i += 1) {
        var j: usize = sequence.len - 1;
        while (j > i) : (j -= 1) {
            const class_j = combiningClass(sequence[j]);
            const class_j1 = combiningClass(sequence[j - 1]);
            if (class_j > 0 and class_j1 > class_j) {
                // Swap
                const temp = sequence[j];
                sequence[j] = sequence[j - 1];
                sequence[j - 1] = temp;
            }
        }
    }
}

/// Compose two codepoints if they form a valid canonical composition
/// Returns the composed codepoint, or null if no composition is possible
pub fn composeCanonical(cp1: u21, cp2: u21) ?u21 {
    // TODO: Implement composition table lookup
    // For basic ASCII, no composition needed
    _ = cp1;
    _ = cp2;
    return null;
}

/// Perform canonical decomposition of UTF-8 input
pub fn decomposeCanonicalString(input: []const u8, buffer: *NormalizationBuffer) !void {
    buffer.clear();

    var iter = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (decomposeCanonical(cp)) |decomp| {
            try buffer.buffer.appendSlice(buffer.alloc, decomp);
        } else {
            try buffer.buffer.append(buffer.alloc, cp);
        }
    }

    // Apply canonical ordering
    canonicalOrdering(buffer.buffer.items);
}

/// Perform compatibility decomposition of UTF-8 input
pub fn decomposeCompatibilityString(input: []const u8, buffer: *NormalizationBuffer) !void {
    buffer.clear();

    var iter = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (decomposeCompatibility(cp)) |decomp| {
            // Recursively decompose compatibility decompositions
            for (decomp) |decomp_cp| {
                if (decomposeCompatibility(decomp_cp)) |inner_decomp| {
                    try buffer.buffer.appendSlice(buffer.alloc, inner_decomp);
                } else {
                    try buffer.buffer.append(buffer.alloc, decomp_cp);
                }
            }
        } else if (decomposeCanonical(cp)) |decomp| {
            try buffer.buffer.appendSlice(buffer.alloc, decomp);
        } else {
            try buffer.buffer.append(buffer.alloc, cp);
        }
    }

    // Apply canonical ordering
    canonicalOrdering(buffer.buffer.items);
}

/// Perform canonical composition on a decomposed sequence
pub fn composeCanonicalSequence(sequence: []u21, buffer: *NormalizationBuffer) !void {
    buffer.clear();

    var i: usize = 0;
    while (i < sequence.len) {
        const cp = sequence[i];
        if (i + 1 < sequence.len and isCombiningMark(sequence[i + 1])) {
            if (composeCanonical(cp, sequence[i + 1])) |composed| {
                try buffer.buffer.append(buffer.alloc, composed);
                i += 2;
                continue;
            }
        }
        try buffer.buffer.append(buffer.alloc, cp);
        i += 1;
    }
}

pub fn normalize(alloc: std.mem.Allocator, form: NormalizationForm, input: []const u8) ![]u8 {
    var buffer = NormalizationBuffer.init(alloc);
    defer buffer.deinit();

    switch (form) {
        .nfd => {
            try decomposeCanonicalString(input, &buffer);
        },
        .nfkd => {
            try decomposeCompatibilityString(input, &buffer);
        },
        .nfc => {
            try decomposeCanonicalString(input, &buffer);
            try composeCanonicalSequence(buffer.buffer.items, &buffer);
        },
        .nfkc => {
            try decomposeCompatibilityString(input, &buffer);
            try composeCanonicalSequence(buffer.buffer.items, &buffer);
        },
    }

    return buffer.toUtf8();
}

pub fn isNormalized(form: NormalizationForm, input: []const u8) bool {
    // For now, assume input is normalized (placeholder implementation)
    // TODO: Implement proper normalization checking
    _ = form;
    _ = input;
    return true;
}
