const std = @import("std");
const gcode = @import("lib.zig");

pub const TerminalSlice = struct {
    bytes: []const u8,
    display_width: usize,
    truncated: bool,
};

pub const GraphemeSpan = struct {
    start: usize,
    end: usize,
    display_width: usize,

    pub fn bytes(self: GraphemeSpan, text: []const u8) []const u8 {
        return text[self.start..self.end];
    }
};

fn clusterWidth(cluster: []const u8) usize {
    return gcode.stringWidth(cluster);
}

pub const TerminalString = struct {
    bytes: []const u8,
    ambiguous_width_policy: gcode.AmbiguousWidthPolicy = .narrow,

    pub fn init(bytes: []const u8) TerminalString {
        return .{ .bytes = bytes };
    }

    pub fn initWithPolicy(bytes: []const u8, policy: gcode.AmbiguousWidthPolicy) TerminalString {
        return .{ .bytes = bytes, .ambiguous_width_policy = policy };
    }

    pub fn displayWidth(self: TerminalString) usize {
        return gcode.stringWidthWithPolicy(self.bytes, self.ambiguous_width_policy);
    }

    pub fn nextBoundary(self: TerminalString, byte_index: usize) usize {
        return gcode.findNextGrapheme(self.bytes, @min(byte_index, self.bytes.len));
    }

    pub fn previousBoundary(self: TerminalString, byte_index: usize) usize {
        return gcode.findPreviousGrapheme(self.bytes, @min(byte_index, self.bytes.len));
    }

    pub fn graphemeAt(self: TerminalString, grapheme_index: usize) ?GraphemeSpan {
        var iter = gcode.graphemeIterator(self.bytes);
        var byte_start: usize = 0;
        var index: usize = 0;
        while (iter.next()) |cluster| : (index += 1) {
            const byte_end = byte_start + cluster.len;
            defer byte_start = byte_end;
            if (index == grapheme_index) {
                return .{
                    .start = byte_start,
                    .end = byte_end,
                    .display_width = gcode.stringWidthWithPolicy(cluster, self.ambiguous_width_policy),
                };
            }
        }
        return null;
    }

    pub fn sliceGraphemes(self: TerminalString, start_index: usize, count: usize) []const u8 {
        if (count == 0) return self.bytes[0..0];

        var iter = gcode.graphemeIterator(self.bytes);
        var byte_start: usize = 0;
        var slice_start: ?usize = null;
        var slice_end: usize = 0;
        var index: usize = 0;

        while (iter.next()) |cluster| : (index += 1) {
            const byte_end = byte_start + cluster.len;
            defer byte_start = byte_end;

            if (index == start_index) slice_start = byte_start;
            if (slice_start != null and index < start_index + count) slice_end = byte_end;
            if (index + 1 >= start_index + count) break;
        }

        const start = slice_start orelse return self.bytes[0..0];
        return self.bytes[start..slice_end];
    }

    pub fn truncateWidth(self: TerminalString, max_width: usize) TerminalSlice {
        var iter = gcode.graphemeIterator(self.bytes);
        var byte_start: usize = 0;
        var byte_end: usize = 0;
        var width: usize = 0;

        while (iter.next()) |cluster| {
            const next_width = width + gcode.stringWidthWithPolicy(cluster, self.ambiguous_width_policy);
            if (next_width > max_width) {
                return .{ .bytes = self.bytes[0..byte_end], .display_width = width, .truncated = true };
            }
            width = next_width;
            byte_end = byte_start + cluster.len;
            byte_start = byte_end;
        }

        return .{ .bytes = self.bytes[0..byte_end], .display_width = width, .truncated = false };
    }

    pub fn deletePrevious(self: TerminalString, byte_index: usize) []const u8 {
        const end = @min(byte_index, self.bytes.len);
        const start = self.previousBoundary(end);
        return self.bytes[start..end];
    }
};

test "terminal string boundaries and width" {
    const text = TerminalString.init("a界e\u{0301}😀");
    try std.testing.expectEqual(@as(usize, 6), text.displayWidth());

    const first = text.nextBoundary(0);
    try std.testing.expectEqual(@as(usize, 1), first);
    const second = text.nextBoundary(first);
    try std.testing.expectEqualStrings("界", text.bytes[first..second]);
    try std.testing.expectEqual(first, text.previousBoundary(second));
}

test "terminal string ambiguous width policy" {
    const narrow = TerminalString.initWithPolicy("a·", .narrow);
    const wide = TerminalString.initWithPolicy("a·", .wide);

    try std.testing.expectEqual(@as(usize, 2), narrow.displayWidth());
    try std.testing.expectEqual(@as(usize, 3), wide.displayWidth());
}

test "terminal string slicing and truncation" {
    const text = TerminalString.init("a界e\u{0301}😀");

    try std.testing.expectEqualStrings("界e\u{0301}", text.sliceGraphemes(1, 2));

    const truncated = text.truncateWidth(4);
    try std.testing.expect(truncated.truncated);
    try std.testing.expectEqual(@as(usize, 4), truncated.display_width);
    try std.testing.expectEqualStrings("a界e\u{0301}", truncated.bytes);

    const deleted = text.deletePrevious(text.bytes.len);
    try std.testing.expectEqualStrings("😀", deleted);
}
