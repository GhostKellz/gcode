const std = @import("std");
const gcode = @import("gcode");

pub fn main() !void {
    const stdout = std.debug;

    stdout.print("gcode benchmark comparison scaffold\n", .{});
    stdout.print("Unicode version: {s}\n", .{gcode.unicode_version});
    stdout.print("Generated table stages: {d}/{d}/{d}\n", .{ gcode.table.stage1.len, gcode.table.stage2.len, gcode.table.stage3.len });

    const corpus = [_][]const u8{
        "plain ASCII terminal text",
        "mixed CJK 世界 terminal text",
        "emoji 😀🏳️‍🌈👨‍👩‍👧‍👦 terminal text",
        "combining e\u{0301} a\u{0308} text",
    };

    var total_width: usize = 0;
    var total_clusters: usize = 0;
    for (corpus) |text| {
        total_width += gcode.stringWidth(text);
        var iter = gcode.graphemeIterator(text);
        while (iter.next()) |_| total_clusters += 1;
    }

    stdout.print("gcode corpus width: {d}\n", .{total_width});
    stdout.print("gcode corpus grapheme clusters: {d}\n", .{total_clusters});
    stdout.print("external zg comparison: not configured\n", .{});
    stdout.print("external ziglyph comparison: not configured\n", .{});
    stdout.print("Pin external package versions before publishing comparison numbers.\n", .{});
}
