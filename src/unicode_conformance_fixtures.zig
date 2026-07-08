const std = @import("std");
const gcode = @import("lib.zig");

fn expectGraphemes(input: []const u8, expected: []const []const u8) !void {
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

test "grapheme conformance style fixtures" {
    // GB9: x Extend
    try expectGraphemes("a\u{0308}", &.{"a\u{0308}"});

    // GB9a: x SpacingMark
    try expectGraphemes("\u{0915}\u{093E}", &.{"\u{0915}\u{093E}"});

    // GB11: Extended_Pictographic Extend* ZWJ x Extended_Pictographic
    try expectGraphemes("\u{1F469}\u{1F3FD}\u{200D}\u{1F4BB}", &.{"\u{1F469}\u{1F3FD}\u{200D}\u{1F4BB}"});

    // GB12/GB13: regional indicators pair in twos.
    try expectGraphemes("\u{1F1FA}\u{1F1F8}\u{1F1EF}", &.{ "\u{1F1FA}\u{1F1F8}", "\u{1F1EF}" });
}

test "word conformance style fixtures" {
    // WB5: AHLetter x AHLetter
    try expectWords("hello", &.{"hello"});

    // WB6/WB7: AHLetter x MidLetter x AHLetter
    try expectWords("rock'n'roll", &.{"rock'n'roll"});

    // WB8/WB11/WB12: numeric sequences with punctuation.
    try expectWords("1,234.56", &.{"1,234.56"});

    // WB13a/WB13b: ExtendNumLet sequences.
    try expectWords("abc_def", &.{"abc_def"});
}

test "east asian width conformance style fixtures" {
    try std.testing.expectEqual(@as(u2, 1), gcode.getWidth('A'));
    try std.testing.expectEqual(@as(u2, 2), gcode.getWidth('Ａ'));
    try std.testing.expectEqual(@as(u2, 2), gcode.getWidth('界'));
    try std.testing.expect(gcode.getProperties('·').ambiguous_width);
}

test "normalization conformance style fixtures" {
    const allocator = std.testing.allocator;

    const nfd = try gcode.normalize(allocator, .nfd, "Å");
    defer allocator.free(nfd);
    try std.testing.expectEqualStrings("A\u{030A}", nfd);

    const nfkc = try gcode.normalize(allocator, .nfkc, "①ﬃ");
    defer allocator.free(nfkc);
    try std.testing.expectEqualStrings("1ffi", nfkc);

    try std.testing.expect(gcode.isNormalized(.nfc, "é"));
}

test "case mapping conformance style fixtures" {
    try std.testing.expectEqual(@as(u21, 'A'), gcode.toUpper('a'));
    try std.testing.expectEqual(@as(u21, 'a'), gcode.toLower('A'));
    try std.testing.expectEqual(@as(u21, 'É'), gcode.toUpper('é'));
    try std.testing.expectEqual(@as(u21, 'é'), gcode.toLower('É'));
}
