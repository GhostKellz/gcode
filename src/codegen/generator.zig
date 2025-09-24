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
    Lu,
    Ll,
    Lt,
    Lm,
    Lo, // Letter categories
    Mn,
    Mc,
    Me, // Mark categories
    Nd,
    Nl,
    No, // Number categories
    Pc,
    Pd,
    Ps,
    Pe,
    Pi,
    Pf,
    Po, // Punctuation categories
    Sm,
    Sc,
    Sk,
    So, // Symbol categories
    Zs,
    Zl,
    Zp, // Separator categories
    Cc,
    Cf,
    Cs,
    Co,
    Cn, // Other categories
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

/// Case mappings for a codepoint
pub const CaseMappings = struct {
    uppercase: u21 = 0,
    lowercase: u21 = 0,
    titlecase: u21 = 0,
};

pub const Properties = packed struct {
    /// Codepoint width. We clamp to [0, 2] since terminals handle control
    /// characters and we max out at 2 for wide characters.
    width: u2 = 0,

    /// Grapheme boundary class.
    grapheme_boundary_class: GraphemeBoundaryClass = .invalid,

    /// Uppercase mapping (0 if no mapping)
    uppercase: u21 = 0,

    /// Lowercase mapping (0 if no mapping)
    lowercase: u21 = 0,

    /// Titlecase mapping (0 if no mapping)
    titlecase: u21 = 0,

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

        /// Mapping of a block to its index in the stage2 array.
        const BlockMap = std.HashMap(
            Block,
            u16,
            struct {
                pub fn hash(ctx: @This(), k: Block) u64 {
                    _ = ctx;
                    var hasher = std.hash.Wyhash.init(0);
                    std.hash.autoHashStrat(&hasher, k, .DeepRecursive);
                    return hasher.final();
                }

                pub fn eql(ctx: @This(), a: Block, b: Block) bool {
                    _ = ctx;
                    return std.mem.eql(u16, &a, &b);
                }
            },
            std.hash_map.default_max_load_percentage,
        );

        ctx: Context = undefined,

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

            pub fn writeZig(self: @This(), alloc: std.mem.Allocator, buf: *std.ArrayList(u8)) !void {
                try buf.appendSlice(alloc, "lut.Tables(props.Properties){\n");
                try buf.appendSlice(alloc, "    .stage1 = &[_]u16{\n");

                for (self.stage1, 0..) |value, i| {
                    if (i % 16 == 0) try buf.appendSlice(alloc, "        ");
                    const str = try std.fmt.allocPrint(alloc, "{}, ", .{value});
                    defer alloc.free(str);
                    try buf.appendSlice(alloc, str);
                    if (i % 16 == 15 or i == self.stage1.len - 1) try buf.appendSlice(alloc, "\n");
                }
                try buf.appendSlice(alloc, "    },\n");

                try buf.appendSlice(alloc, "    .stage2 = &[_]u16{\n");
                for (self.stage2, 0..) |value, i| {
                    if (i % 16 == 0) try buf.appendSlice(alloc, "        ");
                    const str = try std.fmt.allocPrint(alloc, "{}, ", .{value});
                    defer alloc.free(str);
                    try buf.appendSlice(alloc, str);
                    if (i % 16 == 15 or i == self.stage2.len - 1) try buf.appendSlice(alloc, "\n");
                }
                try buf.appendSlice(alloc, "    },\n");

                try buf.appendSlice(alloc, "    .stage3 = &[_]props.Properties{\n");
                for (self.stage3, 0..) |value, i| {
                    if (i % 8 == 0) try buf.appendSlice(alloc, "        ");
                    const str = try std.fmt.allocPrint(alloc, ".{{ .width = {}, .grapheme_boundary_class = .{s}, .uppercase = {}, .lowercase = {}, .titlecase = {} }},\n", .{
                        value.width,
                        @tagName(value.grapheme_boundary_class),
                        value.uppercase,
                        value.lowercase,
                        value.titlecase,
                    });
                    defer alloc.free(str);
                    try buf.appendSlice(alloc, str);
                    if (i % 8 == 7 or i == self.stage3.len - 1) try buf.appendSlice(alloc, "\n");
                }
                try buf.appendSlice(alloc, "    },\n");
                try buf.appendSlice(alloc, "}");
            }

            pub fn writeZigToString(self: @This(), alloc: std.mem.Allocator) ![]u8 {
                var buf = try std.ArrayList(u8).initCapacity(alloc, 0);
                errdefer buf.deinit(alloc);

                try self.writeZig(alloc, &buf);
                return try buf.toOwnedSlice(alloc);
            }

            pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
                alloc.free(self.stage1);
                alloc.free(self.stage2);
                alloc.free(self.stage3);
            }
        };

        pub fn generate(self: *const Self, alloc: std.mem.Allocator) !Tables {
            // Maps block => stage2 index
            var blocks_map = BlockMap.init(alloc);
            defer blocks_map.deinit();

            // Our stages
            var stage1 = try std.ArrayList(u16).initCapacity(alloc, 0);
            defer stage1.deinit(alloc);
            var stage2 = try std.ArrayList(u16).initCapacity(alloc, 0);
            defer stage2.deinit(alloc);
            var stage3 = try std.ArrayList(Properties).initCapacity(alloc, 0);
            defer stage3.deinit(alloc);

            var block: Block = undefined;
            var block_len: u16 = 0;
            var unique_block_count: u16 = 0;
            for (0..std.math.maxInt(u21) + 1) |cp| {
                // Get our block value and find the matching result value
                // in our list of possible values in stage3. This way, each
                // possible mapping only gets one entry in stage3.
                const elem = self.ctx.get(@as(u21, @intCast(cp)));
                const block_idx = block_idx: {
                    for (stage3.items, 0..) |item, i| {
                        if (self.ctx.eql(item, elem)) break :block_idx i;
                    }

                    const idx = stage3.items.len;
                    try stage3.append(alloc, elem);
                    break :block_idx idx;
                };

                // The block stores the mapping to the stage3 index
                block[block_len] = std.math.cast(u16, block_idx) orelse return error.BlockTooLarge;
                block_len += 1;

                // If we still have space and we're not done with codepoints,
                // we keep building up the bock. Conversely: we finalize this
                // block if we've filled it or are out of codepoints.
                if (block_len < block_size and cp != std.math.maxInt(u21)) continue;
                if (block_len < block_size) @memset(block[block_len..block_size], 0);

                // Look for the stage2 index for this block. If it doesn't exist
                // we add it to stage2 and update the mapping.
                const gop = try blocks_map.getOrPut(block);
                if (!gop.found_existing) {
                    gop.value_ptr.* = unique_block_count;
                    unique_block_count += 1;
                    for (block[0..block_len]) |entry| try stage2.append(alloc, entry);
                }

                // Add the stage2 index to stage1
                try stage1.append(alloc, gop.value_ptr.*);

                // Reset for next block
                block_len = 0;
            }

            return Tables{
                .stage1 = try stage1.toOwnedSlice(alloc),
                .stage2 = try stage2.toOwnedSlice(alloc),
                .stage3 = try stage3.toOwnedSlice(alloc),
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
    _ = content;
    return std.StringHashMap(u2).init(alloc);
}

fn parseGraphemeBreakProperty(alloc: std.mem.Allocator, content: []const u8) !std.StringHashMap([]const u8) {
    var properties = std.StringHashMap([]const u8).init(alloc);
    errdefer properties.deinit();

    var start: usize = 0;
    while (std.mem.indexOf(u8, content[start..], "\n")) |end| {
        const line_end = start + end;
        const line = content[start..line_end];
        start = line_end + 1;

        if (line.len == 0 or line[0] == '#') continue;

        // Find first two semicolons
        const first_semi = std.mem.indexOf(u8, line, ";") orelse continue;
        const second_semi = std.mem.indexOf(u8, line[first_semi + 1 ..], ";") orelse continue;

        const range_part = line[0..first_semi];
        const class_part = line[first_semi + 1 .. first_semi + 1 + second_semi];

        if (class_part.len == 0) continue;

        if (std.mem.indexOf(u8, range_part, "..")) |dot_pos| {
            const start_str = range_part[0..dot_pos];
            const end_str = range_part[dot_pos + 2 ..];
            const start_cp = try std.fmt.parseInt(u21, start_str, 16);
            const end_cp = try std.fmt.parseInt(u21, end_str, 16);

            var cp = start_cp;
            while (cp <= end_cp) : (cp += 1) {
                const key = try std.fmt.allocPrint(alloc, "{x}", .{cp});
                try properties.put(key, try alloc.dupe(u8, class_part));
            }
        } else {
            const key = try alloc.dupe(u8, range_part);
            try properties.put(key, try alloc.dupe(u8, class_part));
        }
    }

    return properties;
}

/// Parses UnicodeData.txt and returns case mappings
fn parseUnicodeData(alloc: std.mem.Allocator, content: []const u8) !std.StringHashMap(CaseMappings) {
    var case_mappings = std.StringHashMap(CaseMappings).init(alloc);
    errdefer case_mappings.deinit();

    var start: usize = 0;
    while (std.mem.indexOf(u8, content[start..], "\n")) |end| {
        const line_end = start + end;
        const line = content[start..line_end];
        start = line_end + 1;

        if (line.len == 0) continue;

        // UnicodeData.txt format: codepoint;name;category;...;uppercase;lowercase;titlecase;...
        // Find the semicolons manually
        var semicolons: [15]usize = undefined;
        var semi_count: usize = 0;

        var i: usize = 0;
        while (i < line.len and semi_count < 15) : (i += 1) {
            if (line[i] == ';') {
                semicolons[semi_count] = i;
                semi_count += 1;
            }
        }

        if (semi_count < 14) continue; // Need at least 14 semicolons (15 fields)

        const codepoint_str = line[0..semicolons[0]];
        const uppercase_str = line[semicolons[11] + 1 .. semicolons[12]];
        const lowercase_str = line[semicolons[12] + 1 .. semicolons[13]];
        const titlecase_str = line[semicolons[13] + 1 .. (if (semi_count > 14) semicolons[14] else line.len)];

        const cp = try std.fmt.parseInt(u21, codepoint_str, 16);
        const key = try std.fmt.allocPrint(alloc, "{x}", .{cp});

        var mappings = CaseMappings{};

        // Parse uppercase mapping
        if (uppercase_str.len > 0 and !std.mem.eql(u8, uppercase_str, codepoint_str)) {
            mappings.uppercase = try std.fmt.parseInt(u21, uppercase_str, 16);
        }

        // Parse lowercase mapping
        if (lowercase_str.len > 0 and !std.mem.eql(u8, lowercase_str, codepoint_str)) {
            mappings.lowercase = try std.fmt.parseInt(u21, lowercase_str, 16);
        }

        // Parse titlecase mapping
        if (titlecase_str.len > 0 and !std.mem.eql(u8, titlecase_str, codepoint_str)) {
            mappings.titlecase = try std.fmt.parseInt(u21, titlecase_str, 16);
        }

        // Only store if there are actual mappings
        if (mappings.uppercase != 0 or mappings.lowercase != 0 or mappings.titlecase != 0) {
            try case_mappings.put(key, mappings);
        } else {
            alloc.free(key);
        }
    }

    return case_mappings;
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
    case_map: std.StringHashMap(CaseMappings),
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
        // if (ctx.grapheme_map.get(single_key)) |class_name| {
        //     props.grapheme_boundary_class = mapGraphemeClass(class_name);
        // } else {
        //     std.debug.print("Grapheme class not found\n", .{});
        // }

        // Get case mappings
        if (ctx.case_map.get(single_key)) |mappings| {
            props.uppercase = mappings.uppercase;
            props.lowercase = mappings.lowercase;
            props.titlecase = mappings.titlecase;
        }

        return props;
    }

    pub fn eql(ctx: *const UnicodeGeneratorContext, a: Properties, b: Properties) bool {
        _ = ctx;
        return a.width == b.width and
            a.grapheme_boundary_class == b.grapheme_boundary_class and
            a.uppercase == b.uppercase and
            a.lowercase == b.lowercase and
            a.titlecase == b.titlecase;
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
    // const ud_path = "unicode_data/UnicodeData.txt";

    try downloadFile(alloc, .east_asian_width, eaw_path);
    try downloadFile(alloc, .grapheme_break_property, gbp_path);
    try downloadFile(alloc, .unicode_data, "unicode_data/UnicodeData.txt");

    const eaw_content = try std.fs.cwd().readFileAlloc(eaw_path, alloc, .unlimited);
    defer alloc.free(eaw_content);

    const gbp_content = try std.fs.cwd().readFileAlloc(gbp_path, alloc, .unlimited);
    defer alloc.free(gbp_content);

    const ud_content = try std.fs.cwd().readFileAlloc("unicode_data/UnicodeData.txt", alloc, .unlimited);
    defer alloc.free(ud_content);

    var case_map = try parseUnicodeData(alloc, ud_content);
    defer case_map.deinit();

    std.debug.print("Parsed {} case mappings\n", .{case_map.count()});

    var width_map = try parseEastAsianWidth(alloc, eaw_content);
    defer width_map.deinit();

    var grapheme_map = try parseGraphemeBreakProperty(alloc, gbp_content);
    defer grapheme_map.deinit();

    // Debug output
    // const debug_key = "4E00";
    // const debug_key = "3042..3044";
    const debug_key = "1F600";
    const single_key = try std.fmt.allocPrint(alloc, "{s}", .{debug_key});
    defer alloc.free(single_key);

    std.debug.print("Properties for {s}:\n", .{debug_key});
    var props = Properties{};

    // Manual lookup for testing
    if (width_map.get(single_key)) |width| {
        props.width = width;
    } else {
        std.debug.print("Width not found\n", .{});
    }

    // Check case mappings for 'a' (U+0061)
    const a_key = try std.fmt.allocPrint(alloc, "{x}", .{'a'});
    defer alloc.free(a_key);
    if (case_map.get(a_key)) |mappings| {
        std.debug.print("Case mappings for 'a': uppercase={}, lowercase={}, titlecase={}\n", .{ mappings.uppercase, mappings.lowercase, mappings.titlecase });
    } else {
        std.debug.print("No case mappings found for 'a'\n", .{});
    }
    // if (grapheme_map.get(single_key)) |class_name| {
    //     props.grapheme_boundary_class = mapGraphemeClass(class_name);
    // } else {
    //     std.debug.print("Grapheme class not found\n", .{});
    // }
    //     props.uppercase = mappings.uppercase;
    //     props.lowercase = mappings.lowercase;
    //     props.titlecase = mappings.titlecase;
    // } else {
    //     std.debug.print("Case mappings not found\n", .{});
    // }

    std.debug.print("  Width: {d}\n", .{props.width});
    std.debug.print("  Grapheme Boundary Class: {s}\n", .{@tagName(props.grapheme_boundary_class)});

    // Generate tables
    const ctx = UnicodeGeneratorContext{
        .width_map = width_map,
        .grapheme_map = grapheme_map,
        .case_map = case_map,
        .alloc = alloc,
    };

    // Test generator
    const generator = Generator(UnicodeGeneratorContext){ .ctx = ctx };
    const tables = try generator.generate(alloc);
    defer tables.deinit(alloc);

    const lut_path = "unicode_data/lut.zig";
    var lut_file = try std.fs.cwd().createFile(lut_path, .{});
    defer lut_file.close();

    const lut_content = try tables.writeZigToString(alloc);
    defer alloc.free(lut_content);
    try lut_file.writeAll(lut_content);

    std.log.info("Wrote LUT to {s}", .{lut_path});
}
