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
    other,
    cr,
    lf,
    newline,
    extend,
    regional_indicator,
    format,
    katakana,
    hebrew_letter,
    aletter,
    midletter,
    midnum,
    midnumlet,
    numeric,
    extendnumlet,
    zwj,
    wsegspace,
    single_quote,
    double_quote,
    ebase,
    ebase_gaz,
    emodifier,
    glue_after_zwj,
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
};

/// BiDi class for UAX #9 (Bidirectional Algorithm)
pub const BiDiClass = enum(u5) {
    L,   // Left-to-Right
    R,   // Right-to-Left
    AL,  // Right-to-Left Arabic
    EN,  // European Number
    ES,  // European Number Separator
    ET,  // European Number Terminator
    AN,  // Arabic Number
    CS,  // Common Number Separator
    NSM, // Nonspacing Mark
    BN,  // Boundary Neutral
    B,   // Paragraph Separator
    S,   // Segment Separator
    WS,  // Whitespace
    ON,  // Other Neutrals
    LRE, // Left-to-Right Embedding
    LRO, // Left-to-Right Override
    RLE, // Right-to-Left Embedding
    RLO, // Right-to-Left Override
    PDF, // Pop Directional Format
    LRI, // Left-to-Right Isolate
    RLI, // Right-to-Left Isolate
    FSI, // First Strong Isolate
    PDI, // Pop Directional Isolate
};

/// Script property for text shaping guidance
pub const Script = enum(u8) {
    // Common and inherited
    Common,
    Inherited,

    // Major scripts for terminal use
    Latin,
    Greek,
    Cyrillic,
    Armenian,
    Hebrew,
    Arabic,
    Syriac,
    Thaana,
    Devanagari,
    Bengali,
    Gurmukhi,
    Gujarati,
    Oriya,
    Tamil,
    Telugu,
    Kannada,
    Malayalam,
    Sinhala,
    Thai,
    Lao,
    Tibetan,
    Myanmar,
    Georgian,
    Hangul,
    Ethiopian,
    Cherokee,
    Canadian_Aboriginal,
    Ogham,
    Runic,
    Khmer,
    Mongolian,
    Hiragana,
    Katakana,
    Bopomofo,
    Han,
    Yi,
    Old_Italic,
    Gothic,
    Deseret,
    Tagalog,
    Hanunoo,
    Buhid,
    Tagbanwa,
    Limbu,
    Tai_Le,
    Linear_B,
    Ugaritic,
    Shavian,
    Osmanya,
    Cypriot,
    Braille,
    Buginese,
    Coptic,
    New_Tai_Lue,
    Glagolitic,
    Tifinagh,
    Syloti_Nagri,
    Old_Persian,
    Kharoshthi,
    Balinese,
    Cuneiform,
    Phoenician,
    Phags_Pa,
    Nko,

    // Additional scripts (truncated for space)
    Unknown,
};
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

const WidthInfo = struct {
    width: u2,
    ambiguous: bool,
};

const Composition = struct {
    lead: u21,
    trail: u21,
    result: u21,
};

pub const Properties = packed struct {
    width: u2 = 1,
    ambiguous_width: bool = false,
    grapheme_boundary_class: GraphemeBoundaryClass = .invalid,
    word_break_class: WordBreakClass = .other,
    combining_class: u8 = 0,
    uppercase: u21 = 0,
    lowercase: u21 = 0,
    titlecase: u21 = 0,

    pub fn eql(a: Properties, b: Properties) bool {
        return a.width == b.width and
            a.ambiguous_width == b.ambiguous_width and
            a.grapheme_boundary_class == b.grapheme_boundary_class and
            a.word_break_class == b.word_break_class and
            a.combining_class == b.combining_class and
            a.uppercase == b.uppercase and
            a.lowercase == b.lowercase and
            a.titlecase == b.titlecase;
    }

    pub fn format(
        self: Properties,
        comptime layout: []const u8,
        opts: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = layout;
        _ = opts;
        try writer.print(
            ".{{ .width = {d}, .ambiguous_width = {}, .grapheme_boundary_class = .{s}, .word_break_class = .{s}, .combining_class = {d}, .uppercase = {d}, .lowercase = {d}, .titlecase = {d} }}",
            .{
                self.width,
                self.ambiguous_width,
                @tagName(self.grapheme_boundary_class),
                @tagName(self.word_break_class),
                self.combining_class,
                self.uppercase,
                self.lowercase,
                self.titlecase,
            },
        );
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
                try buf.appendSlice(
                    alloc,
                    "//! Unicode lookup tables generated at build time.\n" ++
                        "//! This file is generated by the codegen system and should not be edited manually.\n\n" ++
                        "const props = @import(\"properties.zig\");\n" ++
                        "const lut = @import(\"lut.zig\");\n\n" ++
                        "pub const tables = lut.Tables(props.Properties){\n",
                );
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
                    const str = try std.fmt.allocPrint(
                        alloc,
                        ".{{ .width = {d}, .ambiguous_width = {}, .grapheme_boundary_class = .{s}, .word_break_class = .{s}, .combining_class = {d}, .uppercase = {d}, .lowercase = {d}, .titlecase = {d} }},\n",
                        .{
                            value.width,
                            value.ambiguous_width,
                            @tagName(value.grapheme_boundary_class),
                            @tagName(value.word_break_class),
                            value.combining_class,
                            value.uppercase,
                            value.lowercase,
                            value.titlecase,
                        },
                    );
                    defer alloc.free(str);
                    try buf.appendSlice(alloc, str);
                    if (i % 8 == 7 or i == self.stage3.len - 1) try buf.appendSlice(alloc, "\n");
                }
                try buf.appendSlice(alloc, "    },\n");
                try buf.appendSlice(alloc, "};\n");
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

fn readAllAlloc(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const size = std.math.cast(usize, stat.size) orelse return error.FileTooLarge;

    const buffer = try alloc.alloc(u8, size);
    errdefer alloc.free(buffer);

    const read_len = try file.readAll(buffer);
    if (read_len != size) return error.UnexpectedEndOfFile;

    return buffer;
}

fn parseCodepointRange(range_text: []const u8) !struct { start: u21, end: u21 } {
    if (std.mem.indexOf(u8, range_text, "..")) |pos| {
        const start_str = std.mem.trim(u8, range_text[0..pos], " \t");
        const end_str = std.mem.trim(u8, range_text[pos + 2 ..], " \t");
        return .{
            .start = try std.fmt.parseInt(u21, start_str, 16),
            .end = try std.fmt.parseInt(u21, end_str, 16),
        };
    }

    const single = try std.fmt.parseInt(u21, std.mem.trim(u8, range_text, " \t"), 16);
    return .{ .start = single, .end = single };
}

fn parseEastAsianWidth(alloc: std.mem.Allocator, content: []const u8) !std.AutoHashMap(u21, WidthInfo) {
    var map = std.AutoHashMap(u21, WidthInfo).init(alloc);
    errdefer map.deinit();

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        const semi = std.mem.indexOfScalar(u8, line, ';') orelse continue;
        const range_part = std.mem.trim(u8, line[0..semi], " \t");
        const class_part = std.mem.trim(u8, line[semi + 1 ..], " \t");
        if (class_part.len == 0) continue;

        const range = try parseCodepointRange(range_part);
        const info = blk: {
            if (std.mem.eql(u8, class_part, "W") or std.mem.eql(u8, class_part, "F")) {
                break :blk WidthInfo{ .width = 2, .ambiguous = false };
            }
            if (std.mem.eql(u8, class_part, "A")) {
                break :blk WidthInfo{ .width = 1, .ambiguous = true };
            }
            break :blk WidthInfo{ .width = 1, .ambiguous = false };
        };

        var cp = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(cp, info);
        }
    }

    return map;
}

fn parseGraphemeBreakProperty(alloc: std.mem.Allocator, content: []const u8) !std.AutoHashMap(u21, GraphemeBoundaryClass) {
    var map = std.AutoHashMap(u21, GraphemeBoundaryClass).init(alloc);
    errdefer map.deinit();

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const semi = std.mem.indexOfScalar(u8, line, ';') orelse continue;
        const range_part = std.mem.trim(u8, line[0..semi], " \t");
        const class_part = std.mem.trim(u8, line[semi + 1 ..], " \t");
        if (class_part.len == 0) continue;

        const comment_idx = std.mem.indexOfScalar(u8, class_part, '#');
        const class_name = if (comment_idx) |idx|
            std.mem.trim(u8, class_part[0..idx], " \t")
        else
            class_part;
        if (class_name.len == 0) continue;

        const klass = mapGraphemeClass(class_name) orelse continue;
        const range = try parseCodepointRange(range_part);
        var cp = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(cp, klass);
        }
    }

    return map;
}

fn parseWordBreakProperty(alloc: std.mem.Allocator, content: []const u8) !std.AutoHashMap(u21, WordBreakClass) {
    var map = std.AutoHashMap(u21, WordBreakClass).init(alloc);
    errdefer map.deinit();

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const semi = std.mem.indexOfScalar(u8, line, ';') orelse continue;
        const range_part = std.mem.trim(u8, line[0..semi], " \t");
        const class_part = std.mem.trim(u8, line[semi + 1 ..], " \t");
        if (class_part.len == 0) continue;

        const comment_idx = std.mem.indexOfScalar(u8, class_part, '#');
        const class_name = if (comment_idx) |idx|
            std.mem.trim(u8, class_part[0..idx], " \t")
        else
            class_part;
        if (class_name.len == 0) continue;

        const klass = mapWordBreakClass(class_name) orelse continue;
        const range = try parseCodepointRange(range_part);
        var cp = range.start;
        while (cp <= range.end) : (cp += 1) {
            try map.put(cp, klass);
        }
    }

    return map;
}

const UnicodeDataSet = struct {
    alloc: std.mem.Allocator,
    case_map: std.AutoHashMap(u21, CaseMappings),
    canonical: std.AutoHashMap(u21, []const u21),
    compatibility: std.AutoHashMap(u21, []const u21),
    combining: std.AutoHashMap(u21, u8),
    categories: std.AutoHashMap(u21, GeneralCategory),

    pub fn deinit(self: *UnicodeDataSet) void {
        var canon_iter = self.canonical.iterator();
        while (canon_iter.next()) |entry| {
            self.alloc.free(entry.value_ptr.*);
        }
        self.canonical.deinit();

        var compat_iter = self.compatibility.iterator();
        while (compat_iter.next()) |entry| {
            self.alloc.free(entry.value_ptr.*);
        }
        self.compatibility.deinit();

        self.case_map.deinit();
        self.combining.deinit();
        self.categories.deinit();
    }
};

/// Parses UnicodeData.txt and returns case mappings
fn parseUnicodeData(
    alloc: std.mem.Allocator,
    content: []const u8,
) !UnicodeDataSet {
    var case_map = std.AutoHashMap(u21, CaseMappings).init(alloc);
    errdefer case_map.deinit();
    var canonical = std.AutoHashMap(u21, []const u21).init(alloc);
    errdefer canonical.deinit();
    var compatibility = std.AutoHashMap(u21, []const u21).init(alloc);
    errdefer compatibility.deinit();
    var combining = std.AutoHashMap(u21, u8).init(alloc);
    errdefer combining.deinit();
    var categories = std.AutoHashMap(u21, GeneralCategory).init(alloc);
    errdefer categories.deinit();

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;

        var fields_iter = std.mem.splitScalar(u8, line, ';');
        var fields: [15][]const u8 = undefined;
        var count: usize = 0;
        while (fields_iter.next()) |field| {
            if (count >= fields.len) break;
            fields[count] = std.mem.trim(u8, field, " \t");
            count += 1;
        }
        if (count < 14) continue;

        const cp = try std.fmt.parseInt(u21, fields[0], 16);

        if (mapGeneralCategory(fields[2])) |category| {
            try categories.put(cp, category);
        }

        if (fields[3].len > 0) {
            const ccc = std.fmt.parseInt(u8, fields[3], 10) catch 0;
            if (ccc != 0) try combining.put(cp, ccc);
        }

        if (try parseDecomposition(alloc, fields[5])) |decomp| {
            if (decomp.compatibility) {
                try compatibility.put(cp, decomp.sequence);
            } else {
                try canonical.put(cp, decomp.sequence);
            }
        }

        var mappings = CaseMappings{};
        if (fields[12].len > 0 and !std.mem.eql(u8, fields[12], fields[0])) {
            mappings.uppercase = std.fmt.parseInt(u21, fields[12], 16) catch 0;
        }
        if (fields[13].len > 0 and !std.mem.eql(u8, fields[13], fields[0])) {
            mappings.lowercase = std.fmt.parseInt(u21, fields[13], 16) catch 0;
        }
        if (fields[14].len > 0 and !std.mem.eql(u8, fields[14], fields[0])) {
            mappings.titlecase = std.fmt.parseInt(u21, fields[14], 16) catch 0;
        }
        if (mappings.uppercase != 0 or mappings.lowercase != 0 or mappings.titlecase != 0) {
            try case_map.put(cp, mappings);
        }
    }

    return .{
        .alloc = alloc,
        .case_map = case_map,
        .canonical = canonical,
        .compatibility = compatibility,
        .combining = combining,
        .categories = categories,
    };
}

fn mapGraphemeClass(name: []const u8) ?GraphemeBoundaryClass {
    if (std.mem.eql(u8, name, "Other")) return .invalid;
    if (std.mem.eql(u8, name, "Extend")) return .extend;
    if (std.mem.eql(u8, name, "Prepend")) return .prepend;
    if (std.mem.eql(u8, name, "SpacingMark")) return .spacing_mark;
    if (std.mem.eql(u8, name, "Regional_Indicator")) return .regional_indicator;
    if (std.mem.eql(u8, name, "Extended_Pictographic")) return .extended_pictographic;
    if (std.mem.eql(u8, name, "L")) return .L;
    if (std.mem.eql(u8, name, "V")) return .V;
    if (std.mem.eql(u8, name, "T")) return .T;
    if (std.mem.eql(u8, name, "LV")) return .LV;
    if (std.mem.eql(u8, name, "LVT")) return .LVT;
    if (std.mem.eql(u8, name, "ZWJ")) return .zwj;
    if (std.mem.eql(u8, name, "Emoji_Modifier")) return .emoji_modifier;
    return null;
}

fn mapWordBreakClass(name: []const u8) ?WordBreakClass {
    if (std.mem.eql(u8, name, "Other")) return .other;
    if (std.mem.eql(u8, name, "CR")) return .cr;
    if (std.mem.eql(u8, name, "LF")) return .lf;
    if (std.mem.eql(u8, name, "Newline")) return .newline;
    if (std.mem.eql(u8, name, "Extend")) return .extend;
    if (std.mem.eql(u8, name, "Regional_Indicator")) return .regional_indicator;
    if (std.mem.eql(u8, name, "Format")) return .format;
    if (std.mem.eql(u8, name, "Katakana")) return .katakana;
    if (std.mem.eql(u8, name, "Hebrew_Letter")) return .hebrew_letter;
    if (std.mem.eql(u8, name, "ALetter")) return .aletter;
    if (std.mem.eql(u8, name, "MidLetter")) return .midletter;
    if (std.mem.eql(u8, name, "MidNum")) return .midnum;
    if (std.mem.eql(u8, name, "MidNumLet")) return .midnumlet;
    if (std.mem.eql(u8, name, "Numeric")) return .numeric;
    if (std.mem.eql(u8, name, "ExtendNumLet")) return .extendnumlet;
    if (std.mem.eql(u8, name, "ZWJ")) return .zwj;
    if (std.mem.eql(u8, name, "WSegSpace")) return .wsegspace;
    if (std.mem.eql(u8, name, "Single_Quote")) return .single_quote;
    if (std.mem.eql(u8, name, "Double_Quote")) return .double_quote;
    if (std.mem.eql(u8, name, "E_Base")) return .ebase;
    if (std.mem.eql(u8, name, "E_Base_GAZ")) return .ebase_gaz;
    if (std.mem.eql(u8, name, "E_Modifier")) return .emodifier;
    if (std.mem.eql(u8, name, "Glue_After_Zwj")) return .glue_after_zwj;
    return null;
}

fn mapGeneralCategory(name: []const u8) ?GeneralCategory {
    inline for (std.meta.fields(GeneralCategory)) |field| {
        if (std.mem.eql(u8, name, field.name)) {
            return @field(GeneralCategory, field.name);
        }
    }
    return null;
}

fn parseDecomposition(
    alloc: std.mem.Allocator,
    field: []const u8,
) !?struct { sequence: []const u21, compatibility: bool } {
    const trimmed = std.mem.trim(u8, field, " \t");
    if (trimmed.len == 0) return null;

    var is_compat: bool = false;
    var data_slice = trimmed;
    if (trimmed[0] == '<') {
        const end_tag = std.mem.indexOfScalar(u8, trimmed, '>') orelse return null;
        is_compat = true;
        data_slice = std.mem.trim(u8, trimmed[end_tag + 1 ..], " \t");
        if (data_slice.len == 0) return null;
    }

    var parts = std.mem.splitScalar(u8, data_slice, ' ');
    var values = std.ArrayListUnmanaged(u21){};
    defer values.deinit(alloc);

    while (parts.next()) |part_raw| {
        const part = std.mem.trim(u8, part_raw, " \t");
        if (part.len == 0) continue;
        try values.append(alloc, try std.fmt.parseInt(u21, part, 16));
    }

    if (values.items.len == 0) return null;

    return .{
        .sequence = try values.toOwnedSlice(alloc),
        .compatibility = is_compat,
    };
}

fn parseComposition(
    alloc: std.mem.Allocator,
    content: []const u8,
    compositions: *std.ArrayList(Composition),
) !void {
    _ = alloc;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        var fields = std.mem.splitScalar(u8, line, ';');
        const lhs = fields.next() orelse continue;
        const rhs = fields.next() orelse continue;
        _ = fields.next();

        const pair = std.mem.trim(u8, lhs, " \t");
        const result = std.mem.trim(u8, rhs, " \t");

        var pair_codes = std.mem.splitScalar(u8, pair, ' ');
        const lead_str = pair_codes.next() orelse continue;
        const trail_str = pair_codes.next() orelse continue;

        const lead = std.fmt.parseInt(u21, lead_str, 16) catch continue;
        const trail = std.fmt.parseInt(u21, trail_str, 16) catch continue;
        const composed = std.fmt.parseInt(u21, result, 16) catch continue;

        try compositions.append(.{ .lead = lead, .trail = trail, .result = composed });
    }
}

pub const UnicodeGeneratorContext = struct {
    width_map: *std.AutoHashMap(u21, WidthInfo),
    grapheme_map: *std.AutoHashMap(u21, GraphemeBoundaryClass),
    word_break_map: *std.AutoHashMap(u21, WordBreakClass),
    case_map: *std.AutoHashMap(u21, CaseMappings),
    combining_map: *std.AutoHashMap(u21, u8),
    general_category_map: *std.AutoHashMap(u21, GeneralCategory),
    extended_pictographic: *std.AutoHashMap(u21, void),
    emoji_modifier: *std.AutoHashMap(u21, void),
    emoji_modifier_base: *std.AutoHashMap(u21, void),

    pub fn get(ctx: *const UnicodeGeneratorContext, cp: u21) Properties {
        var props = Properties{};

        if (cp < 0x20 or (cp >= 0x7F and cp <= 0x9F)) {
            props.width = 0;
        } else if (ctx.width_map.get(cp)) |info| {
            props.width = info.width;
            props.ambiguous_width = info.ambiguous;
        } else {
            props.width = 1;
        }

        if (ctx.general_category_map.get(cp)) |category| switch (category) {
            .Mn, .Me => props.width = 0,
            else => {},
        };

        if (ctx.grapheme_map.get(cp)) |klass| {
            props.grapheme_boundary_class = klass;
        }

        if (props.grapheme_boundary_class == .extended_pictographic) {
            if (ctx.emoji_modifier_base.contains(cp)) {
                props.grapheme_boundary_class = .extended_pictographic_base;
            } else if (ctx.emoji_modifier.contains(cp)) {
                props.grapheme_boundary_class = .emoji_modifier;
            }
        }

        if (ctx.word_break_map.get(cp)) |wb| {
            props.word_break_class = wb;
        }

        if (ctx.combining_map.get(cp)) |ccc| {
            props.combining_class = ccc;
        }

        if (ctx.case_map.get(cp)) |mappings| {
            props.uppercase = mappings.uppercase;
            props.lowercase = mappings.lowercase;
            props.titlecase = mappings.titlecase;
        }

        return props;
    }

    pub fn eql(ctx: *const UnicodeGeneratorContext, a: Properties, b: Properties) bool {
        _ = ctx;
        return Properties.eql(a, b);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    std.log.info("gcode Unicode table generator starting...", .{});

    const temp_dir = "unicode_data";
    std.fs.cwd().makeDir(temp_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const eaw_path = "unicode_data/EastAsianWidth.txt";
    const gbp_path = "unicode_data/GraphemeBreakProperty.txt";
    const wbp_path = "unicode_data/WordBreakProperty.txt";
    const ud_path = "unicode_data/UnicodeData.txt";

    try downloadFile(alloc, .east_asian_width, eaw_path);
    try downloadFile(alloc, .grapheme_break_property, gbp_path);
    try downloadFile(alloc, .word_break_property, wbp_path);
    try downloadFile(alloc, .unicode_data, ud_path);

    const eaw_content = try readAllAlloc(alloc, eaw_path);
    defer alloc.free(eaw_content);

    const gbp_content = try readAllAlloc(alloc, gbp_path);
    defer alloc.free(gbp_content);

    const wbp_content = try readAllAlloc(alloc, wbp_path);
    defer alloc.free(wbp_content);

    const ud_content = try readAllAlloc(alloc, ud_path);
    defer alloc.free(ud_content);

    var width_map = try parseEastAsianWidth(alloc, eaw_content);
    defer width_map.deinit();

    var grapheme_map = try parseGraphemeBreakProperty(alloc, gbp_content);
    defer grapheme_map.deinit();

    var word_break_map = try parseWordBreakProperty(alloc, wbp_content);
    defer word_break_map.deinit();

    var unicode_data = try parseUnicodeData(alloc, ud_content);
    defer unicode_data.deinit();

    var extended_pictographic = std.AutoHashMap(u21, void).init(alloc);
    defer extended_pictographic.deinit();

    var emoji_modifier = std.AutoHashMap(u21, void).init(alloc);
    defer emoji_modifier.deinit();

    var emoji_modifier_base = std.AutoHashMap(u21, void).init(alloc);
    defer emoji_modifier_base.deinit();

    const context = UnicodeGeneratorContext{
        .width_map = &width_map,
        .grapheme_map = &grapheme_map,
        .word_break_map = &word_break_map,
        .case_map = &unicode_data.case_map,
        .combining_map = &unicode_data.combining,
        .general_category_map = &unicode_data.categories,
        .extended_pictographic = &extended_pictographic,
        .emoji_modifier = &emoji_modifier,
        .emoji_modifier_base = &emoji_modifier_base,
    };

    const TableGenerator = Generator(UnicodeGeneratorContext);
    var generator = TableGenerator{ .ctx = context };

    const tables = try generator.generate(alloc);
    defer tables.deinit(alloc);

    const output_path = "src/unicode_tables.zig";
    const zig_source = try tables.writeZigToString(alloc);
    defer alloc.free(zig_source);

    var out_file = try std.fs.cwd().createFile(output_path, .{ .truncate = true, .read = false });
    defer out_file.close();
    try out_file.writeAll(zig_source);

    std.log.info("Generated Unicode tables with {d} unique property buckets", .{tables.stage3.len});
}
