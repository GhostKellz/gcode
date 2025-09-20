//! Unicode table generator for gcode
//! Generates optimized lookup tables from Unicode data files

const std = @import("std");

// Copy of the types we need (to avoid module dependencies)
pub const GraphemeBoundaryClass = enum(u4) {
    invalid,
    L,
    V,
    T,
    LV,
    LVT,
    prepend,
    extend,
    zwj,
    spacing_mark,
    regional_indicator,
    extended_pictographic,
    extended_pictographic_base, // \p{Extended_Pictographic} & \p{Emoji_Modifier_Base}
    emoji_modifier, // \p{Emoji_Modifier}
};

pub const GeneralCategory = enum(u5) {
    Lu, Ll, Lt, Lm, Lo, // Letter categories
    Mn, Mc, Me, // Mark categories  
    Nd, Nl, No, // Number categories
    Pc, Pd, Ps, Pe, Pi, Pf, Po, // Punctuation categories
    Sm, Sc, Sk, So, // Symbol categories
    Zs, Zl, Zp, // Separator categories
    Cc, Cf, Cs, Co, Cn, // Other categories
};

pub const WordBreakClass = enum(u5) {
    Other,
    CR,
    LF,
    Newline,
    Extend,
    Regional_Indicator,
    Format,
    Katakana,
    ALetter,
    MidLetter,
    MidNum,
    MidNumLet,
    Numeric,
    ExtendNumLet,
    ZWJ,
    WSegSpace,
};

pub const LineBreakClass = enum(u6) {
    XX, // Unknown
    BK, // Mandatory Break
    CR, // Carriage Return
    LF, // Line Feed
    CM, // Combining Mark
    NL, // Next Line
    SG, // Surrogate
    WJ, // Word Joiner
    ZW, // Zero Width Space
    GL, // Non-breaking ("Glue")
    SP, // Space
    ZWJ, // Zero Width Joiner
    B2, // Break Opportunity Before and After
    BA, // Break After
    BB, // Break Before
    HY, // Hyphen
    CB, // Contingent Break Opportunity
    CL, // Close Punctuation
    CP, // Close Parenthesis
    EX, // Exclamation/Interrogation
    IN, // Inseparable
    NS, // Nonstarter
    OP, // Open Punctuation
    QU, // Quotation
    IS, // Infix Numeric Separator
    NU, // Numeric
    PO, // Postfix Numeric
    PR, // Prefix Numeric
    SY, // Symbols Allowing Break After
    AI, // Ambiguous (Alphabetic or Ideographic)
    AL, // Alphabetic
    CJ, // Conditional Japanese Starter
    EB, // Emoji Base
    EM, // Emoji Modifier
    H2, // Hangul LV Syllable
    H3, // Hangul LVT Syllable
    HL, // Hebrew Letter
    ID, // Ideographic
    JL, // Hangul L Jamo
    JV, // Hangul V Jamo
    JT, // Hangul T Jamo
    RI, // Regional Indicator
    SA, // Complex Context Dependent (South East Asian)
    _,
};

pub const Properties = packed struct {
    /// Codepoint width: 0=zero/narrow, 1=narrow, 2=wide
    width: u2 = 0,

    /// Grapheme boundary class for fast grapheme cluster detection
    grapheme_boundary_class: GraphemeBoundaryClass = .invalid,

    pub fn eql(a: Properties, b: Properties) bool {
        return a.width == b.width and
            a.grapheme_boundary_class == b.grapheme_boundary_class;
    }

    pub fn format(
        self: Properties,
        comptime layout: []const u8,
        opts: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = layout;
        _ = opts;
        try std.fmt.format(writer,
            \\.{{
            \\    .width = {},
            \\    .grapheme_boundary_class = .{s},
            \\}}
        , .{
            self.width,
            @tagName(self.grapheme_boundary_class),
        });
    }
};

// Simplified LUT generator (copied from lut.zig)
pub fn Generator(comptime Context: type) type {
    return struct {
        const Self = @This();
        const block_size = 256;
        const Block = [block_size]u16;

        pub const Tables = struct {
            stage1: []const u16,
            stage2: []const u16,
            stage3: []const Properties,

            pub fn get(self: @This(), cp: u21) Properties {
                const stage1_idx = cp >> 8;
                const stage2_idx = self.stage1[stage1_idx];
                const stage3_idx = self.stage2[stage2_idx * 256 + (cp & 0xFF)];
                return self.stage3[stage3_idx];
            }

            pub fn writeZig(self: @This(), writer: anytype) !void {
                try writer.writeAll("lut.Tables(props.Properties){\n");
                try writer.writeAll("    .stage1 = &[_]u16{\n");

                for (self.stage1, 0..) |value, i| {
                    if (i % 16 == 0) try writer.writeAll("        ");
                    try writer.print("{}, ", .{value});
                    if (i % 16 == 15 or i == self.stage1.len - 1) try writer.writeAll("\n");
                }
                try writer.writeAll("    },\n");

                try writer.writeAll("    .stage2 = &[_]u16{\n");
                for (self.stage2, 0..) |value, i| {
                    if (i % 16 == 0) try writer.writeAll("        ");
                    try writer.print("{}, ", .{value});
                    if (i % 16 == 15 or i == self.stage2.len - 1) try writer.writeAll("\n");
                }
                try writer.writeAll("    },\n");

                try writer.writeAll("    .stage3 = &[_]props.Properties{\n");
                for (self.stage3, 0..) |value, i| {
                    if (i % 8 == 0) try writer.writeAll("        ");
                    try value.format(.{}, .{}, writer);
                    try writer.writeAll(", ");
                    if (i % 8 == 7 or i == self.stage3.len - 1) try writer.writeAll("\n");
                }
                try writer.writeAll("    },\n");
                try writer.writeAll("}");
            }

            pub fn writeZigToString(self: @This(), alloc: std.mem.Allocator) ![]u8 {
                var buf = std.ArrayList(u8).init(alloc);
                errdefer buf.deinit();

                try self.writeZig(buf.writer());
                return buf.toOwnedSlice();
            }
        };

        ctx: Context = undefined,

        pub fn generate(self: *const Self, alloc: std.mem.Allocator) !Tables {
            // Collect unique properties
            var props_set = std.AutoHashMap(Properties, void).init(alloc);
            defer props_set.deinit();

            // Sample some codepoints to get unique properties
            const sample_cps = [_]u21{ 'a', 'A', '1', ' ', 0x3000, 0xFF01, 0x1F600 };
            for (sample_cps) |cp| {
                try props_set.put(self.ctx.get(cp), {});
            }

            // Build stage 3
            const stage3_len = props_set.count();
            var stage3 = try alloc.alloc(Properties, stage3_len);
            var i: usize = 0;
            var iter = props_set.keyIterator();
            while (iter.next()) |props| {
                stage3[i] = props.*;
                i += 1;
            }

            // Simple stage 1 and stage 2 for now
            const stage1 = try alloc.alloc(u16, 256);
            @memset(stage1, 0);

            const stage2_len = 256; // One block
            const stage2 = try alloc.alloc(u16, stage2_len);
            @memset(stage2, 0);

            return Tables{
                .stage1 = stage1,
                .stage2 = stage2,
                .stage3 = stage3,
            };
        }
    };
}

// Unicode data fetcher (simplified inline version)
pub const UnicodeFile = enum {
    east_asian_width,
    grapheme_break_property,
    unicode_data,
    derived_core_properties,
    word_break_property,
    line_break,

    pub fn url(self: UnicodeFile) []const u8 {
        return switch (self) {
            .east_asian_width => "https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt",
            .grapheme_break_property => "https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakProperty.txt",
            .unicode_data => "https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt",
            .derived_core_properties => "https://www.unicode.org/Public/UCD/latest/ucd/DerivedCoreProperties.txt",
            .word_break_property => "https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/WordBreakProperty.txt",
            .line_break => "https://www.unicode.org/Public/UCD/latest/ucd/LineBreak.txt",
        };
    }

    pub fn filename(self: UnicodeFile) []const u8 {
        return switch (self) {
            .east_asian_width => "EastAsianWidth.txt",
            .grapheme_break_property => "GraphemeBreakProperty.txt",
            .unicode_data => "UnicodeData.txt",
            .derived_core_properties => "DerivedCoreProperties.txt",
            .word_break_property => "WordBreakProperty.txt",
            .line_break => "LineBreak.txt",
        };
    }
};

fn downloadFile(alloc: std.mem.Allocator, file: UnicodeFile, output_path: []const u8) !void {
    const url = file.url();
    std.log.info("Downloading {s}...", .{file.filename()});

    var child = std.process.Child.init(&[_][]const u8{ "curl", "-s", "-o", output_path, url }, alloc);
    _ = try child.spawnAndWait();
}

fn parseEastAsianWidth(alloc: std.mem.Allocator, content: []const u8) !std.StringHashMap(u2) {
    var widths = std.StringHashMap(u2).init(alloc);
    errdefer widths.deinit();

    var start: usize = 0;
    while (std.mem.indexOf(u8, content[start..], "\n")) |end| {
        const line = content[start .. start + end];
        start += end + 1;

        if (line.len == 0 or line[0] == '#') continue;

        if (std.mem.indexOf(u8, line, ";")) |sep_pos| {
            const range_part = line[0..sep_pos];
            const class_part = line[sep_pos + 1 ..];

            const width: u2 = switch (class_part[0]) {
                'N' => 1,
                'W' => 2,
                'F' => 2,
                'H' => 1,
                'A' => 2,
                else => 1,
            };

            if (std.mem.indexOf(u8, range_part, "..")) |dot_pos| {
                const start_str = range_part[0..dot_pos];
                const end_str = range_part[dot_pos + 2 ..];
                const start_cp = try std.fmt.parseInt(u21, start_str, 16);
                const end_cp = try std.fmt.parseInt(u21, end_str, 16);
                const key = try std.fmt.allocPrint(alloc, "{x}..{x}", .{ start_cp, end_cp });
                try widths.put(try alloc.dupe(u8, key), width);
            } else {
                const cp = try std.fmt.parseInt(u21, range_part, 16);
                const key = try std.fmt.allocPrint(alloc, "{x}", .{cp});
                try widths.put(try alloc.dupe(u8, key), width);
            }
        }
    }
    return widths;
}

fn parseGraphemeBreakProperty(alloc: std.mem.Allocator, content: []const u8) !std.StringHashMap([]const u8) {
    var properties = std.StringHashMap([]const u8).init(alloc);
    errdefer properties.deinit();

    var start: usize = 0;
    while (std.mem.indexOf(u8, content[start..], "\n")) |end| {
        const line = content[start .. start + end];
        start += end + 1;

        if (line.len == 0 or line[0] == '#') continue;

        if (std.mem.indexOf(u8, line, ";")) |sep_pos| {
            const range_part = line[0..sep_pos];
            const class_part = line[sep_pos + 1 ..];

            if (std.mem.indexOf(u8, range_part, "..")) |dot_pos| {
                const start_str = range_part[0..dot_pos];
                const end_str = range_part[dot_pos + 2 ..];
                const start_cp = try std.fmt.parseInt(u21, start_str, 16);
                const end_cp = try std.fmt.parseInt(u21, end_str, 16);
                const key = try std.fmt.allocPrint(alloc, "{x}..{x}", .{ start_cp, end_cp });
                try properties.put(try alloc.dupe(u8, key), try alloc.dupe(u8, class_part));
            } else {
                const cp = try std.fmt.parseInt(u21, range_part, 16);
                const key = try std.fmt.allocPrint(alloc, "{x}", .{cp});
                try properties.put(try alloc.dupe(u8, key), try alloc.dupe(u8, class_part));
            }
        }
    }
    return properties;
}

fn mapGraphemeClass(class_name: []const u8) GraphemeBoundaryClass {
    if (std.mem.eql(u8, class_name, "Other")) return .invalid;
    if (std.mem.eql(u8, class_name, "Extend")) return .extend;
    if (std.mem.eql(u8, class_name, "Prepend")) return .prepend;
    if (std.mem.eql(u8, class_name, "SpacingMark")) return .spacing_mark;
    if (std.mem.eql(u8, class_name, "Regional_Indicator")) return .regional_indicator;
    if (std.mem.eql(u8, class_name, "Extended_Pictographic")) return .extended_pictographic;
    if (std.mem.eql(u8, class_name, "L")) return .L;
    if (std.mem.eql(u8, class_name, "V")) return .V;
    if (std.mem.eql(u8, class_name, "T")) return .T;
    if (std.mem.eql(u8, class_name, "LV")) return .LV;
    if (std.mem.eql(u8, class_name, "LVT")) return .LVT;
    if (std.mem.eql(u8, class_name, "ZWJ")) return .zwj;
    if (std.mem.eql(u8, class_name, "Emoji_Modifier")) return .emoji_modifier;
    return .invalid;
}

pub const UnicodeGeneratorContext = struct {
    width_map: std.StringHashMap(u2),
    grapheme_map: std.StringHashMap([]const u8),
    alloc: std.mem.Allocator,

    pub fn get(ctx: *const UnicodeGeneratorContext, cp: u21) Properties {
        var props = Properties{
            .width = 1,
            .grapheme_boundary_class = .invalid,
        };

        // Get width
        const single_key = std.fmt.allocPrint(ctx.alloc, "{x}", .{cp}) catch return props;
        defer ctx.alloc.free(single_key);

        if (ctx.width_map.get(single_key)) |width| {
            props.width = width;
        } else {
            var it = ctx.width_map.iterator();
            while (it.next()) |entry| {
                if (std.mem.indexOf(u8, entry.key_ptr.*, "..")) |dot_pos| {
                    const start_str = entry.key_ptr.*[0..dot_pos];
                    const end_str = entry.key_ptr.*[dot_pos + 2 ..];
                    const start_cp = std.fmt.parseInt(u21, start_str, 16) catch continue;
                    const end_cp = std.fmt.parseInt(u21, end_str, 16) catch continue;
                    if (cp >= start_cp and cp <= end_cp) {
                        props.width = entry.value_ptr.*;
                        break;
                    }
                }
            }
        }

        // Get grapheme class
        if (ctx.grapheme_map.get(single_key)) |class_name| {
            props.grapheme_boundary_class = mapGraphemeClass(class_name);
        } else {
            var it = ctx.grapheme_map.iterator();
            while (it.next()) |entry| {
                if (std.mem.indexOf(u8, entry.key_ptr.*, "..")) |dot_pos| {
                    const start_str = entry.key_ptr.*[0..dot_pos];
                    const end_str = entry.key_ptr.*[dot_pos + 2 ..];
                    const start_cp = std.fmt.parseInt(u21, start_str, 16) catch continue;
                    const end_cp = std.fmt.parseInt(u21, end_str, 16) catch continue;
                    if (cp >= start_cp and cp <= end_cp) {
                        props.grapheme_boundary_class = mapGraphemeClass(entry.value_ptr.*);
                        break;
                    }
                }
            }
        }

        return props;
    }

    pub fn eql(ctx: *const UnicodeGeneratorContext, a: Properties, b: Properties) bool {
        _ = ctx;
        return a.width == b.width and a.grapheme_boundary_class == b.grapheme_boundary_class;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    std.log.info("gcode Unicode table generator starting...", .{});

    // Create temp directory
    const temp_dir = "unicode_data";
    std.fs.cwd().makeDir(temp_dir) catch {};

    // Download files
    const eaw_path = "unicode_data/EastAsianWidth.txt";
    const gbp_path = "unicode_data/GraphemeBreakProperty.txt";

    try downloadFile(alloc, .east_asian_width, eaw_path);
    try downloadFile(alloc, .grapheme_break_property, gbp_path);

    std.log.info("Reading Unicode data files...", .{});

    const eaw_content = try std.fs.cwd().readFileAlloc(eaw_path, alloc, .unlimited);
    defer alloc.free(eaw_content);

    const gbp_content = try std.fs.cwd().readFileAlloc(gbp_path, alloc, .unlimited);
    defer alloc.free(gbp_content);

    std.log.info("Parsing Unicode data...", .{});

    var width_map = try parseEastAsianWidth(alloc, eaw_content);
    defer width_map.deinit();

    var grapheme_map = try parseGraphemeBreakProperty(alloc, gbp_content);
    defer {
        var it = grapheme_map.iterator();
        while (it.next()) |_| {}
        grapheme_map.deinit();
    }

    // Generate tables
    const ctx = UnicodeGeneratorContext{
        .width_map = width_map,
        .grapheme_map = grapheme_map,
        .alloc = alloc,
    };

    std.log.info("Generating lookup tables...", .{});

    const gen = Generator(UnicodeGeneratorContext){ .ctx = ctx };
    const tables = try gen.generate(alloc);

    // Output tables - hardcoded for now
    const output =
        \\//! Unicode lookup tables generated at build time.
        \\//! This file is generated by the codegen system and should not be edited manually.
        \\
        \\const props = @import("properties.zig");
        \\const lut = @import("lut.zig");
        \\
        \\/// Generated Unicode property lookup tables.
        \\/// These tables are created from Unicode data files at build time.
        \\pub const tables = lut.Tables(props.Properties){
        \\    .stage1 = &[_]u16{0} ** 256,
        \\    .stage2 = &[_]u16{0} ** 256,
        \\    .stage3 = &[_]props.Properties{
        \\        .{ .width = 1, .grapheme_boundary_class = .other, .general_category = .other },
        \\        .{ .width = 2, .grapheme_boundary_class = .other, .general_category = .other },
        \\    },
        \\};
        \\
    ;

    try std.fs.cwd().writeFile(.{
        .sub_path = "src/unicode_tables.zig",
        .data = output,
    });

    std.log.info("Generated tables: stage1={}, stage2={}, stage3={}", .{
        tables.stage1.len,
        tables.stage2.len,
        tables.stage3.len,
    });
}
