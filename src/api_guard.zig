const std = @import("std");
const gcode = @import("gcode");

test "stable terminal API is exported" {
    _ = gcode.Properties;
    _ = gcode.AmbiguousWidthPolicy;
    _ = gcode.GraphemeBoundaryClass;
    _ = gcode.GraphemeBreakState;
    _ = gcode.GraphemeIterator;
    _ = gcode.ReverseGraphemeIterator;
    _ = gcode.WordBreakState;
    _ = gcode.WordIterator;
    _ = gcode.ReverseWordIterator;
    _ = gcode.TerminalString;
    _ = gcode.TerminalSlice;
    _ = gcode.GraphemeSpan;
    _ = gcode.NormalizationForm;
    _ = gcode.unicode_version;
    _ = gcode.unicode_data_files;

    _ = &gcode.getProperties;
    _ = &gcode.getWidth;
    _ = &gcode.getWidthWithPolicy;
    _ = &gcode.stringWidth;
    _ = &gcode.stringWidthWithPolicy;
    _ = &gcode.graphemeIterator;
    _ = &gcode.wordIterator;
    _ = &gcode.findPreviousGrapheme;
    _ = &gcode.findNextGrapheme;
    _ = &gcode.toLower;
    _ = &gcode.toUpper;
    _ = &gcode.toTitle;
    _ = &gcode.normalize;
    _ = &gcode.isNormalized;
}

test "stable terminal API behavior smoke" {
    try std.testing.expectEqualStrings("16.0.0", gcode.unicode_version);
    try std.testing.expectEqual(@as(u2, 2), gcode.getWidth('界'));
    try std.testing.expectEqual(@as(usize, 3), gcode.stringWidth("a界"));

    var iter = gcode.graphemeIterator("e\u{0301}");
    try std.testing.expectEqualStrings("e\u{0301}", iter.next().?);
    try std.testing.expect(iter.next() == null);

    const allocator = std.testing.allocator;
    const nfd = try gcode.normalize(allocator, .nfd, "é");
    defer allocator.free(nfd);
    try std.testing.expectEqualStrings("e\u{0301}", nfd);

    const terminal = gcode.TerminalString.init("a界e\u{0301}");
    try std.testing.expectEqual(@as(usize, 4), terminal.displayWidth());
    try std.testing.expectEqualStrings("界", terminal.sliceGraphemes(1, 1));

    const wide = gcode.TerminalString.initWithPolicy("a·", .wide);
    try std.testing.expectEqual(@as(usize, 3), wide.displayWidth());
}
