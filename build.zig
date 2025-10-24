const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = .{
        .use_double_precision = b.option(
            bool,
            "use_double_precision",
            "Enable double precision",
        ) orelse false,
        .enable_asserts = b.option(
            bool,
            "enable_asserts",
            "Enable assertions",
        ) orelse (optimize == .Debug),
        .enable_cross_platform_determinism = b.option(
            bool,
            "enable_cross_platform_determinism",
            "Enables cross-platform determinism",
        ) orelse true,
        .enable_debug_renderer = b.option(
            bool,
            "enable_debug_renderer",
            "Enable debug renderer",
        ) orelse false,
        .shared = b.option(
            bool,
            "shared",
            "Build JoltC as shared lib",
        ) orelse false,
        .no_exceptions = b.option(
            bool,
            "no_exceptions",
            "Disable C++ Exceptions",
        ) orelse true,
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }

    const options_module = options_step.createModule();
    const mod = b.addModule("jolt_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "joltc_options",
                .module = options_module,
            },
        },
    });

    const joltc_dep = b.dependency("joltc", .{});
    const jph_dep = b.dependency("jolt_physics", .{});
    mod.addIncludePath(joltc_dep.path("include"));

    const jolt = b.addLibrary(
        .{
            .name = "jolt",
            .linkage = if (options.shared) .dynamic else .static,
            .root_module = b.createModule(
                .{
                    .target = target,
                    .optimize = optimize,
                },
            ),
        },
    );

    if (options.shared and target.result.os.tag == .windows) {
        jolt.root_module.addCMacro("JPH_API", "extern __declspec(dllexport)");
    }
    b.installArtifact(jolt);
    jolt.installHeader(joltc_dep.path("include/joltc.h"), "joltc.h");

    jolt.addIncludePath(joltc_dep.path("include"));
    jolt.addIncludePath(jph_dep.path(""));
    jolt.linkLibC();
    if (target.result.abi != .msvc) {
        jolt.linkLibCpp();
    } else {
        jolt.linkSystemLibrary("advapi32");
    }

    const c_flags = &.{
        "-std=c++17",
        if (options.no_exceptions) "-fno-exceptions" else "",
        "-fno-access-control",
        "-fno-sanitize=undefined",
    };

    jolt.addCSourceFiles(.{
        .root = joltc_dep.path("src"),
        .files = &.{
            "joltc.cpp",
        },
        .flags = c_flags,
    });

    const allocator = b.allocator;
    var cpp_files = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    defer cpp_files.deinit(allocator);

    const jolt_path = jph_dep.path("Jolt");
    const jph_root = try jolt_path.getPath3(b, null).toString(allocator);
    try collectCppFiles(allocator, jph_root, &cpp_files);

    var rel_files = try std.ArrayList([]const u8).initCapacity(allocator, cpp_files.items.len);
    defer rel_files.deinit(allocator);

    for (cpp_files.items) |abs_path| {
        const rel_path = try std.fs.path.relative(allocator, jph_root, abs_path);
        try rel_files.append(allocator, rel_path);
    }

    jolt.addCSourceFiles(.{
        .root = jph_dep.path("Jolt"),
        .files = rel_files.items,
        .flags = c_flags,
    });

    mod.linkLibrary(jolt);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}

fn collectCppFiles(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    files: *std.ArrayList([]const u8),
) !void {
    var dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
        switch (entry.kind) {
            .file => {
                if (std.mem.endsWith(u8, entry.name, ".cpp")) {
                    try files.append(allocator, full_path);
                }
            },
            .directory => try collectCppFiles(allocator, full_path, files),
            else => {},
        }
    }
}
