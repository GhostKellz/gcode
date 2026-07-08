const std = @import("std");
const gcode = @import("lib.zig");

fn expectClusters(input: []const u8, expected: []const []const u8) !void {
    var iter = gcode.graphemeIterator(input);
    for (expected) |want| {
        const got = iter.next() orelse return error.MissingCluster;
        try std.testing.expectEqualStrings(want, got);
    }
    try std.testing.expect(iter.next() == null);
}

fn expectWords(input: []const u8, expected: []const []const u8) !void {
    var iter = gcode.wordIterator(input);
    for (expected) |want| {
        const got = iter.next() orelse return error.MissingWordSegment;
        try std.testing.expectEqualStrings(want, got);
    }
    try std.testing.expect(iter.next() == null);
}

test "terminal width policy fixtures" {
    try std.testing.expectEqual(@as(u2, 1), gcode.getWidth('x'));
    try std.testing.expectEqual(@as(u2, 2), gcode.getWidth('界'));
    try std.testing.expectEqual(@as(u2, 2), gcode.getWidth('😀'));
    try std.testing.expectEqual(@as(u2, 0), gcode.getWidth('\u{200D}'));
    try std.testing.expectEqual(@as(u2, 0), gcode.getWidth('\u{FE0F}'));
    try std.testing.expectEqual(@as(u2, 0), gcode.getWidth('\u{0007}'));
    try std.testing.expect(gcode.getProperties('·').ambiguous_width);
    try std.testing.expectEqual(@as(u2, 1), gcode.getWidthWithPolicy('·', .narrow));
    try std.testing.expectEqual(@as(u2, 2), gcode.getWidthWithPolicy('·', .wide));

    try std.testing.expectEqual(@as(usize, 5), gcode.stringWidth("plain"));
    try std.testing.expectEqual(@as(usize, 6), gcode.stringWidth("a界b😀"));
    try std.testing.expectEqual(@as(usize, 1), gcode.stringWidth("e\u{0301}"));
    try std.testing.expectEqual(@as(usize, 3), gcode.stringWidthWithPolicy("a·", .wide));
}

test "grapheme cluster terminal fixtures" {
    try expectClusters("abc", &.{ "a", "b", "c" });
    try expectClusters("e\u{0301}x", &.{ "e\u{0301}", "x" });
    // GB9c: KA + VIRAMA + SSA (क्ष) is one Indic conjunct cluster.
    try expectClusters("\u{0915}\u{094D}\u{0937}", &.{"\u{0915}\u{094D}\u{0937}"});
    try expectClusters("\u{1F1FA}\u{1F1F8}\u{1F1EF}\u{1F1F5}", &.{ "\u{1F1FA}\u{1F1F8}", "\u{1F1EF}\u{1F1F5}" });
    try expectClusters("\u{1F44D}\u{1F3FD}!", &.{ "\u{1F44D}\u{1F3FD}", "!" });
    try expectClusters("1\u{FE0F}\u{20E3}", &.{"1\u{FE0F}\u{20E3}"});
}

test "cursor movement fixtures" {
    const combining = "e\u{0301}x";
    const after_first = gcode.findNextGrapheme(combining, 0);
    try std.testing.expectEqual(@as(usize, "e\u{0301}".len), after_first);
    try std.testing.expectEqual(@as(usize, 0), gcode.findPreviousGrapheme(combining, after_first));

    const emoji = "a\u{1F469}\u{200D}\u{1F4BB}b";
    const first = gcode.findNextGrapheme(emoji, 0);
    const second = gcode.findNextGrapheme(emoji, first);
    try std.testing.expectEqualStrings("a", emoji[0..first]);
    try std.testing.expectEqualStrings("\u{1F469}\u{200D}\u{1F4BB}", emoji[first..second]);
    try std.testing.expectEqual(first, gcode.findPreviousGrapheme(emoji, second));
}

test "word boundary terminal fixtures" {
    try expectWords("hello world", &.{ "hello", " ", "world" });
    try expectWords("can't stop", &.{ "can't", " ", "stop" });
    try expectWords("3.1415", &.{"3.1415"});
    try expectWords("abc123", &.{"abc123"});
    try expectWords("\u{1F1FA}\u{1F1F8} ok", &.{ "\u{1F1FA}\u{1F1F8}", " ", "ok" });
}

test "case and normalization fixtures" {
    try std.testing.expectEqual(@as(u21, 'A'), gcode.toUpper('a'));
    try std.testing.expectEqual(@as(u21, 'z'), gcode.toLower('Z'));
    try std.testing.expectEqual(@as(u21, 'A'), gcode.toTitle('a'));

    const allocator = std.testing.allocator;

    const nfd = try gcode.normalize(allocator, .nfd, "é");
    defer allocator.free(nfd);
    try std.testing.expectEqualStrings("e\u{0301}", nfd);

    const nfc = try gcode.normalize(allocator, .nfc, "e\u{0301}");
    defer allocator.free(nfc);
    try std.testing.expectEqualStrings("é", nfc);

    const nfkd = try gcode.normalize(allocator, .nfkd, "①");
    defer allocator.free(nfkd);
    try std.testing.expectEqualStrings("1", nfkd);
}
