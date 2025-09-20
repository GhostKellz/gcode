const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

// This whole file is based on the algorithm described here:
// https://here-be-braces.com/fast-lookup-of-unicode-properties/

/// Creates a type that is able to generate a 3-level lookup table
/// from a Unicode codepoint to a mapping of type Elem. The lookup table
/// generally is expected to be codegen'd and then reloaded, although it
/// can in theory be generated at runtime.
///
/// Context must have two functions:
///   - `get(Context, u21) Elem`: returns the mapping for a given codepoint
///   - `eql(Context, Elem, Elem) bool`: returns true if two mappings are equal
///
pub fn Generator(
    comptime Elem: type,
    comptime Context: type,
) type {
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

        /// Generate the lookup tables. The arrays in the return value
        /// are owned by the caller and must be freed.
        pub fn generate(self: *const Self, alloc: Allocator) !Tables(Elem) {
            // Maps block => stage2 index
            var blocks_map = BlockMap.init(alloc);
            defer blocks_map.deinit();

            // Our stages
            var stage1 = std.ArrayList(u16).init(alloc);
            defer stage1.deinit();
            var stage2 = std.ArrayList(u16).init(alloc);
            defer stage2.deinit();
            var stage3 = std.ArrayList(Elem).init(alloc);
            defer stage3.deinit();

            var block: Block = undefined;
            var block_len: u16 = 0;
            for (0..std.math.maxInt(u21) + 1) |cp| {
                // Get our block value and find the matching result value
                // in our list of possible values in stage3. This way, each
                // possible mapping only gets one entry in stage3.
                const elem = try self.ctx.get(@as(u21, @intCast(cp)));
                const block_idx = block_idx: {
                    for (stage3.items, 0..) |item, i| {
                        if (self.ctx.eql(item, elem)) break :block_idx i;
                    }

                    const idx = stage3.items.len;
                    try stage3.append(elem);
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
                    gop.value_ptr.* = std.math.cast(
                        u16,
                        stage2.items.len,
                    ) orelse return error.Stage2TooLarge;
                    for (block[0..block_len]) |entry| try stage2.append(entry);
                }

                // Add the stage2 index to stage1
                try stage1.append(gop.value_ptr.*);

                // Reset for next block
                block_len = 0;
            }

            return Tables(Elem){
                .stage1 = try stage1.toOwnedSlice(),
                .stage2 = try stage2.toOwnedSlice(),
                .stage3 = try stage3.toOwnedSlice(),
            };
        }
    };
}

/// The generated lookup tables for a given element type.
pub fn Tables(comptime Elem: type) type {
    return struct {
        stage1: []const u16,
        stage2: []const u16,
        stage3: []const Elem,

        /// Get the element for a given codepoint.
        pub fn get(self: @This(), cp: u21) Elem {
            const stage1_idx = cp >> 8;
            const stage2_idx = self.stage1[stage1_idx];
            const stage3_idx = self.stage2[stage2_idx * 256 + (cp & 0xFF)];
            return self.stage3[stage3_idx];
        }

        /// Write the tables in Zig syntax for codegen
        pub fn writeZig(self: @This(), writer: anytype) !void {
            try writer.writeAll("lut.Tables(" ++ @typeName(Elem) ++ "){\n");
            try writer.writeAll("    .stage1 = &[_]u16{\n");

            for (self.stage1, 0..) |value, i| {
                if (i % 16 == 0) try writer.writeAll("        ");
                try writer.print("{}, ", .{value});
                if (i % 16 == 15) try writer.writeAll("\n");
            }
            try writer.writeAll("\n    },\n");

            try writer.writeAll("    .stage2 = &[_]u16{\n");
            for (self.stage2, 0..) |value, i| {
                if (i % 16 == 0) try writer.writeAll("        ");
                try writer.print("{}, ", .{value});
                if (i % 16 == 15) try writer.writeAll("\n");
            }
            try writer.writeAll("\n    },\n");

            try writer.writeAll("    .stage3 = &[_]" ++ @typeName(Elem) ++ "{\n");
            for (self.stage3, 0..) |value, i| {
                if (i % 8 == 0) try writer.writeAll("        ");
                try value.format(.{}, .{}, writer);
                try writer.writeAll(", ");
                if (i % 8 == 7) try writer.writeAll("\n");
            }
            try writer.writeAll("\n    },\n");
            try writer.writeAll("}");
        }
    };
}
