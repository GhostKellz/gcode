# Installation

gcode targets the Zig development version declared in `build.zig.zon` and has no
external package dependencies.

## Fetch

Prefer release tags for reproducible consumers:

```bash
zig fetch --save https://github.com/ghostkellz/gcode/archive/refs/tags/<tag>.tar.gz
```

For local development, use a path dependency from your application checkout.

## Build Integration

```zig
const gcode = b.dependency("gcode", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("gcode", gcode.module("gcode"));
```

## Local Verification

```bash
zig build
zig build test
zig build benchmark
```

`zig build gen` regenerates Unicode tables. Treat generated table updates as a
reviewed change with pinned Unicode source files and expected diffs.
