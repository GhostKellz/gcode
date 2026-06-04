// This whole file is based on the algorithm described here:
// https://here-be-braces.com/fast-lookup-of-unicode-properties/
//
// The table generator that builds these stages lives in
// `src/codegen/generator.zig`; this module only provides the compact runtime
// lookup consumed by the generated `unicode_tables.zig`.

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
    };
}
