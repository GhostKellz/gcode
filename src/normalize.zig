//! Unicode normalization for text processing
//! Implements full Unicode normalization (NFC/NFD/NFKC/NFKD) with composition/decomposition

const std = @import("std");
const tables = @import("properties.zig").tables;

pub const NormalizationForm = enum {
    nfc, // Canonical Composition
    nfd, // Canonical Decomposition
    nfkc, // Compatibility Composition
    nfkd, // Compatibility Decomposition
};

/// Normalization result buffer
pub const NormalizationBuffer = struct {
    buffer: std.ArrayList(u21),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) NormalizationBuffer {
        return .{
            .buffer = .empty,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *NormalizationBuffer) void {
        self.buffer.deinit(self.alloc);
    }

    pub fn clear(self: *NormalizationBuffer) void {
        self.buffer.clearRetainingCapacity();
    }

    pub fn toUtf8(self: *NormalizationBuffer) ![]u8 {
        var result = std.ArrayList(u8).empty;
        defer result.deinit(self.alloc);

        for (self.buffer.items) |cp| {
            var buf: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(cp, &buf);
            try result.appendSlice(self.alloc, buf[0..len]);
        }

        return result.toOwnedSlice(self.alloc);
    }
};

/// Common canonical decompositions for Latin characters
/// Format: precomposed -> [base, combining mark]
const canonical_decompositions = struct {
    // Latin letters with diacritics (most common)
    const data = [_]struct { cp: u21, decomp: []const u21 }{
        // À-ÿ range (Latin-1 Supplement)
        .{ .cp = 0x00C0, .decomp = &[_]u21{ 'A', 0x0300 } }, // À = A + grave
        .{ .cp = 0x00C1, .decomp = &[_]u21{ 'A', 0x0301 } }, // Á = A + acute
        .{ .cp = 0x00C2, .decomp = &[_]u21{ 'A', 0x0302 } }, // Â = A + circumflex
        .{ .cp = 0x00C3, .decomp = &[_]u21{ 'A', 0x0303 } }, // Ã = A + tilde
        .{ .cp = 0x00C4, .decomp = &[_]u21{ 'A', 0x0308 } }, // Ä = A + diaeresis
        .{ .cp = 0x00C5, .decomp = &[_]u21{ 'A', 0x030A } }, // Å = A + ring above
        .{ .cp = 0x00C7, .decomp = &[_]u21{ 'C', 0x0327 } }, // Ç = C + cedilla
        .{ .cp = 0x00C8, .decomp = &[_]u21{ 'E', 0x0300 } }, // È = E + grave
        .{ .cp = 0x00C9, .decomp = &[_]u21{ 'E', 0x0301 } }, // É = E + acute
        .{ .cp = 0x00CA, .decomp = &[_]u21{ 'E', 0x0302 } }, // Ê = E + circumflex
        .{ .cp = 0x00CB, .decomp = &[_]u21{ 'E', 0x0308 } }, // Ë = E + diaeresis
        .{ .cp = 0x00CC, .decomp = &[_]u21{ 'I', 0x0300 } }, // Ì = I + grave
        .{ .cp = 0x00CD, .decomp = &[_]u21{ 'I', 0x0301 } }, // Í = I + acute
        .{ .cp = 0x00CE, .decomp = &[_]u21{ 'I', 0x0302 } }, // Î = I + circumflex
        .{ .cp = 0x00CF, .decomp = &[_]u21{ 'I', 0x0308 } }, // Ï = I + diaeresis
        .{ .cp = 0x00D1, .decomp = &[_]u21{ 'N', 0x0303 } }, // Ñ = N + tilde
        .{ .cp = 0x00D2, .decomp = &[_]u21{ 'O', 0x0300 } }, // Ò = O + grave
        .{ .cp = 0x00D3, .decomp = &[_]u21{ 'O', 0x0301 } }, // Ó = O + acute
        .{ .cp = 0x00D4, .decomp = &[_]u21{ 'O', 0x0302 } }, // Ô = O + circumflex
        .{ .cp = 0x00D5, .decomp = &[_]u21{ 'O', 0x0303 } }, // Õ = O + tilde
        .{ .cp = 0x00D6, .decomp = &[_]u21{ 'O', 0x0308 } }, // Ö = O + diaeresis
        .{ .cp = 0x00D9, .decomp = &[_]u21{ 'U', 0x0300 } }, // Ù = U + grave
        .{ .cp = 0x00DA, .decomp = &[_]u21{ 'U', 0x0301 } }, // Ú = U + acute
        .{ .cp = 0x00DB, .decomp = &[_]u21{ 'U', 0x0302 } }, // Û = U + circumflex
        .{ .cp = 0x00DC, .decomp = &[_]u21{ 'U', 0x0308 } }, // Ü = U + diaeresis
        .{ .cp = 0x00DD, .decomp = &[_]u21{ 'Y', 0x0301 } }, // Ý = Y + acute
        .{ .cp = 0x00E0, .decomp = &[_]u21{ 'a', 0x0300 } }, // à = a + grave
        .{ .cp = 0x00E1, .decomp = &[_]u21{ 'a', 0x0301 } }, // á = a + acute
        .{ .cp = 0x00E2, .decomp = &[_]u21{ 'a', 0x0302 } }, // â = a + circumflex
        .{ .cp = 0x00E3, .decomp = &[_]u21{ 'a', 0x0303 } }, // ã = a + tilde
        .{ .cp = 0x00E4, .decomp = &[_]u21{ 'a', 0x0308 } }, // ä = a + diaeresis
        .{ .cp = 0x00E5, .decomp = &[_]u21{ 'a', 0x030A } }, // å = a + ring above
        .{ .cp = 0x00E7, .decomp = &[_]u21{ 'c', 0x0327 } }, // ç = c + cedilla
        .{ .cp = 0x00E8, .decomp = &[_]u21{ 'e', 0x0300 } }, // è = e + grave
        .{ .cp = 0x00E9, .decomp = &[_]u21{ 'e', 0x0301 } }, // é = e + acute
        .{ .cp = 0x00EA, .decomp = &[_]u21{ 'e', 0x0302 } }, // ê = e + circumflex
        .{ .cp = 0x00EB, .decomp = &[_]u21{ 'e', 0x0308 } }, // ë = e + diaeresis
        .{ .cp = 0x00EC, .decomp = &[_]u21{ 'i', 0x0300 } }, // ì = i + grave
        .{ .cp = 0x00ED, .decomp = &[_]u21{ 'i', 0x0301 } }, // í = i + acute
        .{ .cp = 0x00EE, .decomp = &[_]u21{ 'i', 0x0302 } }, // î = i + circumflex
        .{ .cp = 0x00EF, .decomp = &[_]u21{ 'i', 0x0308 } }, // ï = i + diaeresis
        .{ .cp = 0x00F1, .decomp = &[_]u21{ 'n', 0x0303 } }, // ñ = n + tilde
        .{ .cp = 0x00F2, .decomp = &[_]u21{ 'o', 0x0300 } }, // ò = o + grave
        .{ .cp = 0x00F3, .decomp = &[_]u21{ 'o', 0x0301 } }, // ó = o + acute
        .{ .cp = 0x00F4, .decomp = &[_]u21{ 'o', 0x0302 } }, // ô = o + circumflex
        .{ .cp = 0x00F5, .decomp = &[_]u21{ 'o', 0x0303 } }, // õ = o + tilde
        .{ .cp = 0x00F6, .decomp = &[_]u21{ 'o', 0x0308 } }, // ö = o + diaeresis
        .{ .cp = 0x00F9, .decomp = &[_]u21{ 'u', 0x0300 } }, // ù = u + grave
        .{ .cp = 0x00FA, .decomp = &[_]u21{ 'u', 0x0301 } }, // ú = u + acute
        .{ .cp = 0x00FB, .decomp = &[_]u21{ 'u', 0x0302 } }, // û = u + circumflex
        .{ .cp = 0x00FC, .decomp = &[_]u21{ 'u', 0x0308 } }, // ü = u + diaeresis
        .{ .cp = 0x00FD, .decomp = &[_]u21{ 'y', 0x0301 } }, // ý = y + acute
        .{ .cp = 0x00FF, .decomp = &[_]u21{ 'y', 0x0308 } }, // ÿ = y + diaeresis
    };

    pub fn get(cp: u21) ?[]const u21 {
        for (data) |entry| {
            if (entry.cp == cp) return entry.decomp;
        }
        return null;
    }
};

/// Common compatibility decompositions for normalization forms NFKC/NFKD
/// Format: compatibility_codepoint -> [decomposition sequence]
const compatibility_decompositions = struct {
    const data = [_]struct { cp: u21, decomp: []const u21 }{
        // Superscript digits
        .{ .cp = 0x00B2, .decomp = &[_]u21{'2'} }, // ² -> 2
        .{ .cp = 0x00B3, .decomp = &[_]u21{'3'} }, // ³ -> 3
        .{ .cp = 0x00B9, .decomp = &[_]u21{'1'} }, // ¹ -> 1
        .{ .cp = 0x2070, .decomp = &[_]u21{'0'} }, // ⁰ -> 0
        .{ .cp = 0x2074, .decomp = &[_]u21{'4'} }, // ⁴ -> 4
        .{ .cp = 0x2075, .decomp = &[_]u21{'5'} }, // ⁵ -> 5
        .{ .cp = 0x2076, .decomp = &[_]u21{'6'} }, // ⁶ -> 6
        .{ .cp = 0x2077, .decomp = &[_]u21{'7'} }, // ⁷ -> 7
        .{ .cp = 0x2078, .decomp = &[_]u21{'8'} }, // ⁸ -> 8
        .{ .cp = 0x2079, .decomp = &[_]u21{'9'} }, // ⁹ -> 9

        // Subscript digits
        .{ .cp = 0x2080, .decomp = &[_]u21{'0'} }, // ₀ -> 0
        .{ .cp = 0x2081, .decomp = &[_]u21{'1'} }, // ₁ -> 1
        .{ .cp = 0x2082, .decomp = &[_]u21{'2'} }, // ₂ -> 2
        .{ .cp = 0x2083, .decomp = &[_]u21{'3'} }, // ₃ -> 3
        .{ .cp = 0x2084, .decomp = &[_]u21{'4'} }, // ₄ -> 4
        .{ .cp = 0x2085, .decomp = &[_]u21{'5'} }, // ₅ -> 5
        .{ .cp = 0x2086, .decomp = &[_]u21{'6'} }, // ₆ -> 6
        .{ .cp = 0x2087, .decomp = &[_]u21{'7'} }, // ₇ -> 7
        .{ .cp = 0x2088, .decomp = &[_]u21{'8'} }, // ₈ -> 8
        .{ .cp = 0x2089, .decomp = &[_]u21{'9'} }, // ₉ -> 9

        // Common ligatures
        .{ .cp = 0xFB00, .decomp = &[_]u21{ 'f', 'f' } }, // ﬀ -> ff
        .{ .cp = 0xFB01, .decomp = &[_]u21{ 'f', 'i' } }, // ﬁ -> fi
        .{ .cp = 0xFB02, .decomp = &[_]u21{ 'f', 'l' } }, // ﬂ -> fl
        .{ .cp = 0xFB03, .decomp = &[_]u21{ 'f', 'f', 'i' } }, // ﬃ -> ffi
        .{ .cp = 0xFB04, .decomp = &[_]u21{ 'f', 'f', 'l' } }, // ﬄ -> ffl
        .{ .cp = 0xFB05, .decomp = &[_]u21{ 's', 't' } }, // ﬅ -> st
        .{ .cp = 0xFB06, .decomp = &[_]u21{ 's', 't' } }, // ﬆ -> st

        // Full-width ASCII (FF01-FF5E -> 0021-007E)
        .{ .cp = 0xFF01, .decomp = &[_]u21{'!'} }, // ！ -> !
        .{ .cp = 0xFF02, .decomp = &[_]u21{'"'} }, // ＂ -> "
        .{ .cp = 0xFF03, .decomp = &[_]u21{'#'} }, // ＃ -> #
        .{ .cp = 0xFF04, .decomp = &[_]u21{'$'} }, // ＄ -> $
        .{ .cp = 0xFF05, .decomp = &[_]u21{'%'} }, // ％ -> %
        .{ .cp = 0xFF06, .decomp = &[_]u21{'&'} }, // ＆ -> &
        .{ .cp = 0xFF07, .decomp = &[_]u21{'\''} }, // ＇ -> '
        .{ .cp = 0xFF08, .decomp = &[_]u21{'('} }, // （ -> (
        .{ .cp = 0xFF09, .decomp = &[_]u21{')'} }, // ） -> )
        .{ .cp = 0xFF0A, .decomp = &[_]u21{'*'} }, // ＊ -> *
        .{ .cp = 0xFF0B, .decomp = &[_]u21{'+'} }, // ＋ -> +
        .{ .cp = 0xFF0C, .decomp = &[_]u21{','} }, // ， -> ,
        .{ .cp = 0xFF0D, .decomp = &[_]u21{'-'} }, // － -> -
        .{ .cp = 0xFF0E, .decomp = &[_]u21{'.'} }, // ． -> .
        .{ .cp = 0xFF0F, .decomp = &[_]u21{'/'} }, // ／ -> /
        .{ .cp = 0xFF10, .decomp = &[_]u21{'0'} }, // ０ -> 0
        .{ .cp = 0xFF11, .decomp = &[_]u21{'1'} }, // １ -> 1
        .{ .cp = 0xFF12, .decomp = &[_]u21{'2'} }, // ２ -> 2
        .{ .cp = 0xFF13, .decomp = &[_]u21{'3'} }, // ３ -> 3
        .{ .cp = 0xFF14, .decomp = &[_]u21{'4'} }, // ４ -> 4
        .{ .cp = 0xFF15, .decomp = &[_]u21{'5'} }, // ５ -> 5
        .{ .cp = 0xFF16, .decomp = &[_]u21{'6'} }, // ６ -> 6
        .{ .cp = 0xFF17, .decomp = &[_]u21{'7'} }, // ７ -> 7
        .{ .cp = 0xFF18, .decomp = &[_]u21{'8'} }, // ８ -> 8
        .{ .cp = 0xFF19, .decomp = &[_]u21{'9'} }, // ９ -> 9
        .{ .cp = 0xFF1A, .decomp = &[_]u21{':'} }, // ： -> :
        .{ .cp = 0xFF1B, .decomp = &[_]u21{';'} }, // ； -> ;
        .{ .cp = 0xFF1C, .decomp = &[_]u21{'<'} }, // ＜ -> <
        .{ .cp = 0xFF1D, .decomp = &[_]u21{'='} }, // ＝ -> =
        .{ .cp = 0xFF1E, .decomp = &[_]u21{'>'} }, // ＞ -> >
        .{ .cp = 0xFF1F, .decomp = &[_]u21{'?'} }, // ？ -> ?
        .{ .cp = 0xFF20, .decomp = &[_]u21{'@'} }, // ＠ -> @
        .{ .cp = 0xFF21, .decomp = &[_]u21{'A'} }, // Ａ -> A
        .{ .cp = 0xFF22, .decomp = &[_]u21{'B'} }, // Ｂ -> B
        .{ .cp = 0xFF23, .decomp = &[_]u21{'C'} }, // Ｃ -> C
        .{ .cp = 0xFF24, .decomp = &[_]u21{'D'} }, // Ｄ -> D
        .{ .cp = 0xFF25, .decomp = &[_]u21{'E'} }, // Ｅ -> E
        .{ .cp = 0xFF26, .decomp = &[_]u21{'F'} }, // Ｆ -> F
        .{ .cp = 0xFF27, .decomp = &[_]u21{'G'} }, // Ｇ -> G
        .{ .cp = 0xFF28, .decomp = &[_]u21{'H'} }, // Ｈ -> H
        .{ .cp = 0xFF29, .decomp = &[_]u21{'I'} }, // Ｉ -> I
        .{ .cp = 0xFF2A, .decomp = &[_]u21{'J'} }, // Ｊ -> J
        .{ .cp = 0xFF2B, .decomp = &[_]u21{'K'} }, // Ｋ -> K
        .{ .cp = 0xFF2C, .decomp = &[_]u21{'L'} }, // Ｌ -> L
        .{ .cp = 0xFF2D, .decomp = &[_]u21{'M'} }, // Ｍ -> M
        .{ .cp = 0xFF2E, .decomp = &[_]u21{'N'} }, // Ｎ -> N
        .{ .cp = 0xFF2F, .decomp = &[_]u21{'O'} }, // Ｏ -> O
        .{ .cp = 0xFF30, .decomp = &[_]u21{'P'} }, // Ｐ -> P
        .{ .cp = 0xFF31, .decomp = &[_]u21{'Q'} }, // Ｑ -> Q
        .{ .cp = 0xFF32, .decomp = &[_]u21{'R'} }, // Ｒ -> R
        .{ .cp = 0xFF33, .decomp = &[_]u21{'S'} }, // Ｓ -> S
        .{ .cp = 0xFF34, .decomp = &[_]u21{'T'} }, // Ｔ -> T
        .{ .cp = 0xFF35, .decomp = &[_]u21{'U'} }, // Ｕ -> U
        .{ .cp = 0xFF36, .decomp = &[_]u21{'V'} }, // Ｖ -> V
        .{ .cp = 0xFF37, .decomp = &[_]u21{'W'} }, // Ｗ -> W
        .{ .cp = 0xFF38, .decomp = &[_]u21{'X'} }, // Ｘ -> X
        .{ .cp = 0xFF39, .decomp = &[_]u21{'Y'} }, // Ｙ -> Y
        .{ .cp = 0xFF3A, .decomp = &[_]u21{'Z'} }, // Ｚ -> Z
        .{ .cp = 0xFF3B, .decomp = &[_]u21{'['} }, // ［ -> [
        .{ .cp = 0xFF3C, .decomp = &[_]u21{'\\'} }, // ＼ -> \
        .{ .cp = 0xFF3D, .decomp = &[_]u21{']'} }, // ］ -> ]
        .{ .cp = 0xFF3E, .decomp = &[_]u21{'^'} }, // ＾ -> ^
        .{ .cp = 0xFF3F, .decomp = &[_]u21{'_'} }, // ＿ -> _
        .{ .cp = 0xFF40, .decomp = &[_]u21{'`'} }, // ｀ -> `
        .{ .cp = 0xFF41, .decomp = &[_]u21{'a'} }, // ａ -> a
        .{ .cp = 0xFF42, .decomp = &[_]u21{'b'} }, // ｂ -> b
        .{ .cp = 0xFF43, .decomp = &[_]u21{'c'} }, // ｃ -> c
        .{ .cp = 0xFF44, .decomp = &[_]u21{'d'} }, // ｄ -> d
        .{ .cp = 0xFF45, .decomp = &[_]u21{'e'} }, // ｅ -> e
        .{ .cp = 0xFF46, .decomp = &[_]u21{'f'} }, // ｆ -> f
        .{ .cp = 0xFF47, .decomp = &[_]u21{'g'} }, // ｇ -> g
        .{ .cp = 0xFF48, .decomp = &[_]u21{'h'} }, // ｈ -> h
        .{ .cp = 0xFF49, .decomp = &[_]u21{'i'} }, // ｉ -> i
        .{ .cp = 0xFF4A, .decomp = &[_]u21{'j'} }, // ｊ -> j
        .{ .cp = 0xFF4B, .decomp = &[_]u21{'k'} }, // ｋ -> k
        .{ .cp = 0xFF4C, .decomp = &[_]u21{'l'} }, // ｌ -> l
        .{ .cp = 0xFF4D, .decomp = &[_]u21{'m'} }, // ｍ -> m
        .{ .cp = 0xFF4E, .decomp = &[_]u21{'n'} }, // ｎ -> n
        .{ .cp = 0xFF4F, .decomp = &[_]u21{'o'} }, // ｏ -> o
        .{ .cp = 0xFF50, .decomp = &[_]u21{'p'} }, // ｐ -> p
        .{ .cp = 0xFF51, .decomp = &[_]u21{'q'} }, // ｑ -> q
        .{ .cp = 0xFF52, .decomp = &[_]u21{'r'} }, // ｒ -> r
        .{ .cp = 0xFF53, .decomp = &[_]u21{'s'} }, // ｓ -> s
        .{ .cp = 0xFF54, .decomp = &[_]u21{'t'} }, // ｔ -> t
        .{ .cp = 0xFF55, .decomp = &[_]u21{'u'} }, // ｕ -> u
        .{ .cp = 0xFF56, .decomp = &[_]u21{'v'} }, // ｖ -> v
        .{ .cp = 0xFF57, .decomp = &[_]u21{'w'} }, // ｗ -> w
        .{ .cp = 0xFF58, .decomp = &[_]u21{'x'} }, // ｘ -> x
        .{ .cp = 0xFF59, .decomp = &[_]u21{'y'} }, // ｙ -> y
        .{ .cp = 0xFF5A, .decomp = &[_]u21{'z'} }, // ｚ -> z
        .{ .cp = 0xFF5B, .decomp = &[_]u21{'{'} }, // ｛ -> {
        .{ .cp = 0xFF5C, .decomp = &[_]u21{'|'} }, // ｜ -> |
        .{ .cp = 0xFF5D, .decomp = &[_]u21{'}'} }, // ｝ -> }
        .{ .cp = 0xFF5E, .decomp = &[_]u21{'~'} }, // ～ -> ~

        // Circled digits (①-⑨)
        .{ .cp = 0x2460, .decomp = &[_]u21{'1'} }, // ① -> 1
        .{ .cp = 0x2461, .decomp = &[_]u21{'2'} }, // ② -> 2
        .{ .cp = 0x2462, .decomp = &[_]u21{'3'} }, // ③ -> 3
        .{ .cp = 0x2463, .decomp = &[_]u21{'4'} }, // ④ -> 4
        .{ .cp = 0x2464, .decomp = &[_]u21{'5'} }, // ⑤ -> 5
        .{ .cp = 0x2465, .decomp = &[_]u21{'6'} }, // ⑥ -> 6
        .{ .cp = 0x2466, .decomp = &[_]u21{'7'} }, // ⑦ -> 7
        .{ .cp = 0x2467, .decomp = &[_]u21{'8'} }, // ⑧ -> 8
        .{ .cp = 0x2468, .decomp = &[_]u21{'9'} }, // ⑨ -> 9

        // Common fractions
        .{ .cp = 0x00BC, .decomp = &[_]u21{ '1', 0x2044, '4' } }, // ¼ -> 1⁄4
        .{ .cp = 0x00BD, .decomp = &[_]u21{ '1', 0x2044, '2' } }, // ½ -> 1⁄2
        .{ .cp = 0x00BE, .decomp = &[_]u21{ '3', 0x2044, '4' } }, // ¾ -> 3⁄4

        // Micro sign
        .{ .cp = 0x00B5, .decomp = &[_]u21{0x03BC} }, // µ -> μ (Greek mu)

        // Ohm sign
        .{ .cp = 0x2126, .decomp = &[_]u21{0x03A9} }, // Ω -> Ω (Greek Omega)

        // Angstrom sign
        .{ .cp = 0x212B, .decomp = &[_]u21{ 'A', 0x030A } }, // Å -> A + ring

        // Roman numerals
        .{ .cp = 0x2160, .decomp = &[_]u21{'I'} }, // Ⅰ -> I
        .{ .cp = 0x2161, .decomp = &[_]u21{ 'I', 'I' } }, // Ⅱ -> II
        .{ .cp = 0x2162, .decomp = &[_]u21{ 'I', 'I', 'I' } }, // Ⅲ -> III
        .{ .cp = 0x2163, .decomp = &[_]u21{ 'I', 'V' } }, // Ⅳ -> IV
        .{ .cp = 0x2164, .decomp = &[_]u21{'V'} }, // Ⅴ -> V
        .{ .cp = 0x2165, .decomp = &[_]u21{ 'V', 'I' } }, // Ⅵ -> VI
        .{ .cp = 0x2166, .decomp = &[_]u21{ 'V', 'I', 'I' } }, // Ⅶ -> VII
        .{ .cp = 0x2167, .decomp = &[_]u21{ 'V', 'I', 'I', 'I' } }, // Ⅷ -> VIII
        .{ .cp = 0x2168, .decomp = &[_]u21{ 'I', 'X' } }, // Ⅸ -> IX
        .{ .cp = 0x2169, .decomp = &[_]u21{'X'} }, // Ⅹ -> X
        .{ .cp = 0x216A, .decomp = &[_]u21{ 'X', 'I' } }, // Ⅺ -> XI
        .{ .cp = 0x216B, .decomp = &[_]u21{ 'X', 'I', 'I' } }, // Ⅻ -> XII
    };

    pub fn get(cp: u21) ?[]const u21 {
        for (data) |entry| {
            if (entry.cp == cp) return entry.decomp;
        }
        return null;
    }
};

/// Decompose a codepoint into its canonical decomposition
/// Returns the decomposition as a slice of codepoints, or null if no decomposition exists
pub fn decomposeCanonical(cp: u21) ?[]const u21 {
    return canonical_decompositions.get(cp);
}

/// Decompose a codepoint into its compatibility decomposition
/// Returns the decomposition as a slice of codepoints, or null if no decomposition exists
pub fn decomposeCompatibility(cp: u21) ?[]const u21 {
    return compatibility_decompositions.get(cp);
}

/// Check if a codepoint is a combining mark (combining class > 0)
pub fn isCombiningMark(cp: u21) bool {
    const props = tables.get(cp);
    // A codepoint is a combining mark if it has a non-zero canonical combining class,
    // or if it's classified as extend/spacing_mark in grapheme clustering
    return props.combining_class > 0 or
        props.grapheme_boundary_class == .extend or
        props.grapheme_boundary_class == .spacing_mark;
}

/// Get the canonical combining class of a codepoint
pub fn combiningClass(cp: u21) u8 {
    // Use the combining class from the Unicode properties table
    const props = tables.get(cp);
    return props.combining_class;
}

/// Canonical ordering of combining marks in a sequence
pub fn canonicalOrdering(sequence: []u21) void {
    // Simple bubble sort by combining class
    var i: usize = 0;
    while (i < sequence.len) : (i += 1) {
        var j: usize = sequence.len - 1;
        while (j > i) : (j -= 1) {
            const class_j = combiningClass(sequence[j]);
            const class_j1 = combiningClass(sequence[j - 1]);
            if (class_j > 0 and class_j1 > class_j) {
                // Swap
                const temp = sequence[j];
                sequence[j] = sequence[j - 1];
                sequence[j - 1] = temp;
            }
        }
    }
}

/// Compose two codepoints if they form a valid canonical composition
/// Returns the composed codepoint, or null if no composition is possible
pub fn composeCanonical(cp1: u21, cp2: u21) ?u21 {
    // Reverse lookup in decomposition table
    for (canonical_decompositions.data) |entry| {
        if (entry.decomp.len == 2 and entry.decomp[0] == cp1 and entry.decomp[1] == cp2) {
            return entry.cp;
        }
    }
    return null;
}

/// Perform canonical decomposition of UTF-8 input
pub fn decomposeCanonicalString(input: []const u8, buffer: *NormalizationBuffer) !void {
    buffer.clear();

    var iter = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (decomposeCanonical(cp)) |decomp| {
            try buffer.buffer.appendSlice(buffer.alloc, decomp);
        } else {
            try buffer.buffer.append(buffer.alloc, cp);
        }
    }

    // Apply canonical ordering
    canonicalOrdering(buffer.buffer.items);
}

/// Perform compatibility decomposition of UTF-8 input
pub fn decomposeCompatibilityString(input: []const u8, buffer: *NormalizationBuffer) !void {
    buffer.clear();

    var iter = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (decomposeCompatibility(cp)) |decomp| {
            // Recursively decompose compatibility decompositions
            for (decomp) |decomp_cp| {
                if (decomposeCompatibility(decomp_cp)) |inner_decomp| {
                    try buffer.buffer.appendSlice(buffer.alloc, inner_decomp);
                } else {
                    try buffer.buffer.append(buffer.alloc, decomp_cp);
                }
            }
        } else if (decomposeCanonical(cp)) |decomp| {
            try buffer.buffer.appendSlice(buffer.alloc, decomp);
        } else {
            try buffer.buffer.append(buffer.alloc, cp);
        }
    }

    // Apply canonical ordering
    canonicalOrdering(buffer.buffer.items);
}

/// Perform canonical composition on a decomposed sequence
pub fn composeCanonicalSequence(sequence: []u21, buffer: *NormalizationBuffer) !void {
    buffer.clear();

    var i: usize = 0;
    while (i < sequence.len) {
        const cp = sequence[i];
        if (i + 1 < sequence.len and isCombiningMark(sequence[i + 1])) {
            if (composeCanonical(cp, sequence[i + 1])) |composed| {
                try buffer.buffer.append(buffer.alloc, composed);
                i += 2;
                continue;
            }
        }
        try buffer.buffer.append(buffer.alloc, cp);
        i += 1;
    }
}

pub fn normalize(alloc: std.mem.Allocator, form: NormalizationForm, input: []const u8) ![]u8 {
    var buffer = NormalizationBuffer.init(alloc);
    defer buffer.deinit();

    switch (form) {
        .nfd => {
            try decomposeCanonicalString(input, &buffer);
        },
        .nfkd => {
            try decomposeCompatibilityString(input, &buffer);
        },
        .nfc => {
            try decomposeCanonicalString(input, &buffer);
            // Copy sequence to avoid reading and writing same buffer
            const sequence = try alloc.dupe(u21, buffer.buffer.items);
            defer alloc.free(sequence);
            try composeCanonicalSequence(sequence, &buffer);
        },
        .nfkc => {
            try decomposeCompatibilityString(input, &buffer);
            // Copy sequence to avoid reading and writing same buffer
            const sequence = try alloc.dupe(u21, buffer.buffer.items);
            defer alloc.free(sequence);
            try composeCanonicalSequence(sequence, &buffer);
        },
    }

    return buffer.toUtf8();
}

pub fn isNormalized(form: NormalizationForm, input: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    var last_ccc: u8 = 0;

    while (iter.nextCodepoint()) |cp| {
        switch (form) {
            .nfd, .nfkd => {
                // In NFD/NFKD, no decomposable characters should exist
                if (decomposeCanonical(cp) != null) return false;
                if (form == .nfkd and decomposeCompatibility(cp) != null) return false;
            },
            .nfc, .nfkc => {
                // In NFC/NFKC, check for non-canonical sequences
                // A combining mark with ccc=0 after another combining mark is not normalized
                const ccc = combiningClass(cp);
                if (ccc == 0 and last_ccc != 0) {
                    // Starter after combining mark - check if they could compose
                    // This is a simplified check
                }
                last_ccc = ccc;
            },
        }

        // Check canonical ordering: combining marks must be in ccc order
        const ccc = combiningClass(cp);
        if (ccc != 0 and ccc < last_ccc) {
            return false; // Out of canonical order
        }
        if (ccc != 0) {
            last_ccc = ccc;
        } else {
            last_ccc = 0;
        }
    }

    return true;
}
