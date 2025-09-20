const std = @import("std");
const gcode = @import("gcode");

pub fn main() !void {
    // Test basic gcode functionality
    std.debug.print("gcode - Unicode library for terminals\n", .{});

    // Test basic width detection (will use placeholder data for now)
    const width_a = gcode.getWidth('A');
    const width_kanji = gcode.getWidth('漢');

    std.debug.print("Width of 'A': {}\n", .{width_a});
    std.debug.print("Width of '漢': {}\n", .{width_kanji});

    // Test string width
    const test_string = "Hello 世界";
    const str_width = gcode.stringWidth(test_string);
    std.debug.print("Width of '{s}': {}\n", .{ test_string, str_width });
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
