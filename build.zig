const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = .{
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

    const joltc_dep = b.dependency("joltc", .{});
    const jph_dep = b.dependency("jolt_physics", .{});

    const joltc = b.addLibrary(
        .{
            .name = "joltc",
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
        joltc.root_module.addCMacro("JPH_API", "extern __declspec(dllexport)");
    }
    b.installArtifact(joltc);
    joltc.installHeader(joltc_dep.path("include/joltc.h"), "joltc.h");

    joltc.addIncludePath(joltc_dep.path("include"));
    joltc.addIncludePath(jph_dep.path(""));
    joltc.linkLibC();
    if (target.result.abi != .msvc) {
        joltc.linkLibCpp();
    } else {
        joltc.linkSystemLibrary("advapi32");
    }

    const c_flags = &.{
        "-std=c++17",
        if (options.no_exceptions) "-fno-exceptions" else "",
        "-fno-access-control",
        "-fno-sanitize=undefined",
    };

    joltc.addCSourceFiles(.{
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

    joltc.addCSourceFiles(.{
        .root = jph_dep.path("Jolt"),
        .files = rel_files.items,
        .flags = c_flags,
    });

    const test_mod = b.addModule("joltc_zig_test", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.linkLibrary(joltc);
    const mod_tests = b.addTest(.{
        .root_module = test_mod,
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
