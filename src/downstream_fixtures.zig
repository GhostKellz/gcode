const std = @import("std");
const gcode = @import("lib.zig");

const PhantomCell = struct {
    bytes: []const u8,
    width: usize,
};

fn collectPhantomCells(allocator: std.mem.Allocator, text: []const u8) ![]PhantomCell {
    var cells: std.ArrayList(PhantomCell) = .empty;
    errdefer cells.deinit(allocator);

    var iter = gcode.graphemeIterator(text);
    while (iter.next()) |cluster| {
        try cells.append(allocator, .{ .bytes = cluster, .width = gcode.stringWidth(cluster) });
    }

    return cells.toOwnedSlice(allocator);
}

test "phantom-style render cells preserve grapheme clusters and widths" {
    const allocator = std.testing.allocator;
    const text = "a界e\u{0301}\u{1F469}\u{200D}\u{1F4BB}";
    const cells = try collectPhantomCells(allocator, text);
    defer allocator.free(cells);

    try std.testing.expectEqual(@as(usize, 4), cells.len);
    try std.testing.expectEqualStrings("a", cells[0].bytes);
    try std.testing.expectEqual(@as(usize, 1), cells[0].width);
    try std.testing.expectEqualStrings("界", cells[1].bytes);
    try std.testing.expectEqual(@as(usize, 2), cells[1].width);
    try std.testing.expectEqualStrings("e\u{0301}", cells[2].bytes);
    try std.testing.expectEqual(@as(usize, 1), cells[2].width);
    try std.testing.expectEqualStrings("\u{1F469}\u{200D}\u{1F4BB}", cells[3].bytes);
    try std.testing.expectEqual(@as(usize, 2), cells[3].width);
}

test "ghostshell-style prompt editing uses terminal string boundaries" {
    const prompt = gcode.TerminalString.init("λ echo e\u{0301} \u{1F469}\u{200D}\u{1F4BB}");
    const end = prompt.bytes.len;

    const deleted = prompt.deletePrevious(end);
    try std.testing.expectEqualStrings("\u{1F469}\u{200D}\u{1F4BB}", deleted);

    const before_emoji = prompt.previousBoundary(end);
    const before_space = prompt.previousBoundary(before_emoji);
    try std.testing.expectEqualStrings(" ", prompt.bytes[before_space..before_emoji]);

    const clipped = prompt.truncateWidth(8);
    try std.testing.expect(clipped.truncated);
    try std.testing.expect(clipped.display_width <= 8);
    try std.testing.expect(gcode.utf8.validate(clipped.bytes));
}

test "ghostshell-style wrapping does not split grapheme clusters" {
    const line = gcode.TerminalString.init("abc界de\u{0301}fg");
    const first = line.truncateWidth(6);
    try std.testing.expectEqualStrings("abc界d", first.bytes);
    try std.testing.expectEqual(@as(usize, 6), first.display_width);

    const next_start = first.bytes.len;
    const next_end = line.nextBoundary(next_start);
    try std.testing.expectEqualStrings("e\u{0301}", line.bytes[next_start..next_end]);
}
