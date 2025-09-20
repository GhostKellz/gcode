//! Unicode data fetcher for gcode
//! Downloads and parses Unicode data files needed for property generation

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Unicode data files we need to download
pub const UnicodeFile = enum {
    east_asian_width,
    grapheme_break_property,

    pub fn url(self: UnicodeFile) []const u8 {
        return switch (self) {
            .east_asian_width => "https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt",
            .grapheme_break_property => "https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakProperty.txt",
        };
    }

    pub fn filename(self: UnicodeFile) []const u8 {
        return switch (self) {
            .east_asian_width => "EastAsianWidth.txt",
            .grapheme_break_property => "GraphemeBreakProperty.txt",
        };
    }
};

/// Downloads a Unicode data file to the specified path
pub fn downloadFile(alloc: Allocator, file: UnicodeFile, output_path: []const u8) !void {
    const url = file.url();

    std.log.info("Downloading {s}...", .{file.filename()});

    // Use curl to download the file
    var child = std.process.Child.init(&[_][]const u8{
        "curl",
        "-s", // silent
        "-o",
        output_path,
        url,
    }, alloc);

    _ = try child.spawnAndWait();
}

/// Parses EastAsianWidth.txt and returns a map of codepoint ranges to width classes
pub fn parseEastAsianWidth(alloc: Allocator, content: []const u8) !std.StringHashMap(u2) {
    var widths = std.StringHashMap(u2).init(alloc);
    errdefer widths.deinit();

    var lines = std.mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        // Skip comments and empty lines
        if (line.len == 0 or line[0] == '#') continue;

        // Parse lines like: "0020..007F;N" (Neutral)
        var parts = std.mem.split(u8, line, ";");
        const range_part = parts.next() orelse continue;
        const class_part = parts.next() orelse continue;

        if (class_part.len == 0) continue;

        // Parse width class
        const width: u2 = switch (class_part[0]) {
            'N' => 1, // Narrow
            'W' => 2, // Wide
            'F' => 2, // Fullwidth (treated as wide)
            'H' => 1, // Halfwidth (treated as narrow)
            'A' => 2, // Ambiguous (we treat as wide for safety)
            else => 1, // Default to narrow
        };

        // Parse codepoint range
        if (std.mem.indexOf(u8, range_part, "..")) |dot_pos| {
            const start_str = range_part[0..dot_pos];
            const end_str = range_part[dot_pos + 2 ..];

            const start_cp = try std.fmt.parseInt(u21, start_str, 16);
            const end_cp = try std.fmt.parseInt(u21, end_str, 16);

            // Store as string key for easy lookup
            const key = try std.fmt.allocPrint(alloc, "{x}..{x}", .{ start_cp, end_cp });
            defer alloc.free(key);

            try widths.put(try alloc.dupe(u8, key), width);
        } else {
            // Single codepoint
            const cp = try std.fmt.parseInt(u21, range_part, 16);
            const key = try std.fmt.allocPrint(alloc, "{x}", .{cp});
            defer alloc.free(key);

            try widths.put(try alloc.dupe(u8, key), width);
        }
    }

    return widths;
}

/// Parses GraphemeBreakProperty.txt and returns a map of codepoint ranges to grapheme classes
pub fn parseGraphemeBreakProperty(alloc: Allocator, content: []const u8) !std.StringHashMap([]const u8) {
    var properties = std.StringHashMap([]const u8).init(alloc);
    errdefer properties.deinit();

    var lines = std.mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        // Skip comments and empty lines
        if (line.len == 0 or line[0] == '#') continue;

        // Parse lines like: "0020..007F;Control"
        var parts = std.mem.split(u8, line, ";");
        const range_part = parts.next() orelse continue;
        const class_part = parts.next() orelse continue;

        if (class_part.len == 0) continue;

        // Parse codepoint range and store with class
        if (std.mem.indexOf(u8, range_part, "..")) |dot_pos| {
            const start_str = range_part[0..dot_pos];
            const end_str = range_part[dot_pos + 2 ..];

            const start_cp = try std.fmt.parseInt(u21, start_str, 16);
            const end_cp = try std.fmt.parseInt(u21, end_str, 16);

            const key = try std.fmt.allocPrint(alloc, "{x}..{x}", .{ start_cp, end_cp });
            defer alloc.free(key);

            try properties.put(try alloc.dupe(u8, key), try alloc.dupe(u8, class_part));
        } else {
            // Single codepoint
            const cp = try std.fmt.parseInt(u21, range_part, 16);
            const key = try std.fmt.allocPrint(alloc, "{x}", .{cp});
            defer alloc.free(key);

            try properties.put(try alloc.dupe(u8, key), try alloc.dupe(u8, class_part));
        }
    }

    return properties;
}
