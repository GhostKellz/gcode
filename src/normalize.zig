//! Unicode normalization (UAX #15): NFC, NFD, NFKC, NFKD.
//!
//! Decomposition mappings and the canonical composition table live in the
//! generated `normalize_data.zig`. Hangul syllables are composed and
//! decomposed algorithmically (UAX #15, section 16).

const std = @import("std");
const tables = @import("properties.zig").tables;
const data = @import("normalize_data.zig");

pub const NormalizationForm = enum {
    nfc, // Canonical Composition
    nfd, // Canonical Decomposition
    nfkc, // Compatibility Composition
    nfkd, // Compatibility Decomposition
};

// Hangul algorithmic (de)composition constants (UAX #15).
const SBase: u21 = 0xAC00;
const LBase: u21 = 0x1100;
const VBase: u21 = 0x1161;
const TBase: u21 = 0x11A7;
const LCount: u21 = 19;
const VCount: u21 = 21;
const TCount: u21 = 28;
const NCount: u21 = VCount * TCount; // 588
const SCount: u21 = LCount * NCount; // 11172

/// Canonical combining class from the Unicode properties table.
pub fn combiningClass(cp: u21) u8 {
    return tables.get(cp).combining_class;
}

/// Binary search the one-level decomposition mapping for `cp`.
fn lookupDecomp(cp: u21) ?data.Decomp {
    var lo: usize = 0;
    var hi: usize = data.decomp_index.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const e = data.decomp_index[mid];
        if (cp < e.cp) {
            hi = mid;
        } else if (cp > e.cp) {
            lo = mid + 1;
        } else {
            return e;
        }
    }
    return null;
}

/// Recursively decompose `cp` into `out`. When `compat` is false only
/// canonical mappings are followed; compatibility-only mappings are left in
/// place. Hangul syllables decompose algorithmically.
fn appendDecomp(cp: u21, compat: bool, out: *std.ArrayList(u21), alloc: std.mem.Allocator) !void {
    if (cp >= SBase and cp < SBase + SCount) {
        const si = cp - SBase;
        try out.append(alloc, LBase + si / NCount);
        try out.append(alloc, VBase + (si % NCount) / TCount);
        const t = si % TCount;
        if (t != 0) try out.append(alloc, TBase + t);
        return;
    }

    if (lookupDecomp(cp)) |d| {
        if (d.compat and !compat) {
            try out.append(alloc, cp);
            return;
        }
        var i: usize = 0;
        while (i < d.len) : (i += 1) {
            try appendDecomp(data.decomp_pool[d.start + i], compat, out, alloc);
        }
        return;
    }

    try out.append(alloc, cp);
}

/// Stable canonical ordering: sort combining marks by combining class without
/// reordering across starters (ccc == 0). Marks with equal class keep order.
fn canonicalOrder(seq: []u21) void {
    if (seq.len < 2) return;
    while (true) {
        var swapped = false;
        var i: usize = 1;
        while (i < seq.len) : (i += 1) {
            const a = combiningClass(seq[i - 1]);
            const b = combiningClass(seq[i]);
            if (b != 0 and a != 0 and a > b) {
                const tmp = seq[i - 1];
                seq[i - 1] = seq[i];
                seq[i] = tmp;
                swapped = true;
            }
        }
        if (!swapped) break;
    }
}

/// Canonical composition of two characters, or null if they do not compose.
/// Handles Hangul L+V and LV+T algorithmically and looks up the generated
/// canonical composition table (which already excludes full composition
/// exclusions, singletons, and non-starter decompositions).
fn composePair(a: u21, b: u21) ?u21 {
    // Hangul L + V -> LV
    if (a >= LBase and a < LBase + LCount and b >= VBase and b < VBase + VCount) {
        const li = a - LBase;
        const vi = b - VBase;
        return SBase + (li * NCount + vi * TCount);
    }
    // Hangul LV + T -> LVT
    if (a >= SBase and a < SBase + SCount and (a - SBase) % TCount == 0 and
        b > TBase and b < TBase + TCount)
    {
        return a + (b - TBase);
    }

    var lo: usize = 0;
    var hi: usize = data.compositions.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const e = data.compositions[mid];
        if (a < e.a or (a == e.a and b < e.b)) {
            hi = mid;
        } else if (a > e.a or (a == e.a and b > e.b)) {
            lo = mid + 1;
        } else {
            return e.c;
        }
    }
    return null;
}

/// Canonical composition pass over a fully decomposed, canonically ordered
/// sequence (UAX #15). Composes each character into the last preceding starter
/// it is not blocked from.
fn compose(seq: []const u21, out: *std.ArrayList(u21), alloc: std.mem.Allocator) !void {
    var starter_idx: ?usize = null;
    var last_ccc: i32 = -1;

    for (seq) |ch| {
        const cc: i32 = combiningClass(ch);
        if (starter_idx) |sidx| {
            // Not blocked when a higher combining class follows, or when the
            // character sits immediately after the starter (both ccc == 0).
            if (last_ccc < cc or (cc == 0 and last_ccc == 0)) {
                if (composePair(out.items[sidx], ch)) |composite| {
                    out.items[sidx] = composite;
                    continue;
                }
            }
        }

        try out.append(alloc, ch);
        if (cc == 0) {
            starter_idx = out.items.len - 1;
            last_ccc = 0;
        } else if (starter_idx != null) {
            last_ccc = cc;
        }
    }
}

fn codepointsToUtf8(alloc: std.mem.Allocator, seq: []const u21) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    for (seq) |cp| {
        var buf: [4]u8 = undefined;
        const len = try std.unicode.utf8Encode(cp, &buf);
        try out.appendSlice(alloc, buf[0..len]);
    }
    return out.toOwnedSlice(alloc);
}

pub fn normalize(alloc: std.mem.Allocator, form: NormalizationForm, input: []const u8) ![]u8 {
    const compat = form == .nfkc or form == .nfkd;
    const recompose = form == .nfc or form == .nfkc;

    var decomposed = std.ArrayList(u21).empty;
    defer decomposed.deinit(alloc);

    var iter = std.unicode.Utf8Iterator{ .bytes = input, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        try appendDecomp(cp, compat, &decomposed, alloc);
    }

    canonicalOrder(decomposed.items);

    if (!recompose) {
        return codepointsToUtf8(alloc, decomposed.items);
    }

    var composed = std.ArrayList(u21).empty;
    defer composed.deinit(alloc);
    try compose(decomposed.items, &composed, alloc);
    return codepointsToUtf8(alloc, composed.items);
}

/// A string is in normalization form `form` iff normalizing is a no-op.
pub fn isNormalized(form: NormalizationForm, input: []const u8) bool {
    const norm = normalize(std.heap.page_allocator, form, input) catch return false;
    defer std.heap.page_allocator.free(norm);
    return std.mem.eql(u8, norm, input);
}
