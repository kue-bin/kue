const std = @import("std");

const Build = std.Build;
const Step = Build.Step;
const ResolvedTarget = Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;

const BuildOptions = struct {
    jit: bool,
    plain_lua: bool,
    system_lua: bool,
    system_lua_lib: []const u8,
    system_lua_libdir: []const u8,
    system_lua_incdir: []const u8,
};

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_options = BuildOptions{
        .jit = b.option(bool, "jit", "Enable JIT compilation") orelse true,
        .plain_lua = b.option(bool, "plain-lua", "Use PUC Lua 5.3 (will probably break built-in modules)") orelse false,
        .system_lua = b.option(bool, "system-lua", "Use system's Lua library") orelse false,
        .system_lua_lib = b.option([]const u8, "system-lua-lib", "If 'system-lua' is enabled, this will be used to link the system's library") orelse "lua",
        .system_lua_incdir = b.option([]const u8, "system-lua-incdir", "If 'system-lua' is enabled, this will be used as search path for finding Lua headers") orelse ".",
        .system_lua_libdir = b.option([]const u8, "system-lua-libdir", "If 'system-lua' is enabled, this will be used as search path for linking Lua library") orelse ".",
    };

    const exe = b.addExecutable(.{
        .name = "kue",
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const rpmalloc = b.dependency("rpmalloc", .{});
        exe.linkLibrary(try buildRpMalloc(b, rpmalloc, target, optimize));
        exe.addIncludePath(rpmalloc.path("./rpmalloc"));
    }

    {
        const lunaro = b.dependency("lunaro", .{
            .lua = .lua53,
            .strip = true,
            .target = target,
            .optimize = optimize,
        });

        if (!(build_options.plain_lua or build_options.system_lua)) {
            if (b.lazyDependency("ravi", .{})) |ravi| {
                exe.linkLibrary(try buildRavi(b, build_options, ravi, target, optimize));
                exe.addIncludePath(ravi.path("./include"));
                lunaro.module("lunaro-system").addIncludePath(ravi.path("./include"));
            }
        } else if (build_options.system_lua) {
            exe.addLibraryPath(.{ .cwd_relative = build_options.system_lua_libdir });
            exe.addIncludePath(.{ .cwd_relative = build_options.system_lua_incdir });
            exe.linkSystemLibrary(build_options.system_lua_lib);
            lunaro.module("lunaro-system").addIncludePath(.{ .cwd_relative = build_options.system_lua_incdir });
        }

        if (build_options.plain_lua) {
            exe.root_module.addImport("lunaro", lunaro.module("lunaro-static"));
        } else {
            exe.root_module.addImport("lunaro", lunaro.module("lunaro-system"));
        }
    }

    b.installArtifact(exe);
}

pub fn buildRavi(b: *Build, build_options: BuildOptions, upstream: *Build.Dependency, target: ResolvedTarget, optimize: OptimizeMode) !*Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "ravi",
        .target = target,
        .optimize = optimize,
    });
    const os = target.result.os.tag;
    const arch = target.result.cpu.arch;
    const support_mir = if (build_options.jit)
        (os == .linux and
            arch == .x86_64 or
            arch == .riscv64 or
            arch == .powerpc64le or
            arch == .s390x or
            arch.isAARCH64()) or
            (os == .macos and
            arch == .x86_64 or
            arch.isAARCH64())
    else
        false;

    lib.linkLibC();

    if (support_mir)
        lib.linkLibrary(try buildMir(b, upstream, target, optimize));

    lib.addIncludePath(upstream.path("./include"));
    lib.addIncludePath(upstream.path("./mir/c2mir"));
    lib.addIncludePath(upstream.path("./mir"));

    lib.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = &.{ "./src/bit.c", "./src/lapi.c", "./src/lauxlib.c", "./src/lbaselib.c", "./src/lbitlib.c", "./src/lcode.c", "./src/lcorolib.c", "./src/lctype.c", "./src/ldblib.c", "./src/ldebug.c", "./src/ldo.c", "./src/ldump.c", "./src/lfunc.c", "./src/lgc.c", "./src/linit.c", "./src/liolib.c", "./src/llex.c", "./src/lmathlib.c", "./src/lmem.c", "./src/loadlib.c", "./src/lobject.c", "./src/lopcodes.c", "./src/loslib.c", "./src/lparser.c", "./src/lstate.c", "./src/lstring.c", "./src/lstrlib.c", "./src/ltable.c", "./src/ltablib.c", "./src/ltests.c", "./src/ltm.c", "./src/lundump.c", "./src/lutf8lib.c", "./src/lvm.c", "./src/lzio.c", "./src/ravi_alloc.c", "./src/ravi_jit.c", "./src/ravi_jitshared.c", "./src/ravi_membuf.c", "./src/ravi_profile.c", if (support_mir) "./src/ravi_mirjit.c" else "./src/ravi_nojit.c" },
        .flags = &.{
            "-std=gnu99",
            "-DRAVI_USE_COMPUTED_GOTO=1",
            if (support_mir) "-DUSE_MIRJIT=1" else "",
            switch (target.result.os.tag) {
                .linux => "-DLUA_USE_LINUX",
                .macos => "-DLUA_USE_MACOSX",
                .windows => "-DLUA_USE_WINDOWS",
                else => "-DLUA_USE_POSIX",
            },
            if (optimize == .Debug) "-DLUA_USE_APICHECK" else "",
        },
    });

    return lib;
}

pub fn buildMir(b: *Build, upstream: *Build.Dependency, target: ResolvedTarget, optimize: OptimizeMode) !*Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "mir",
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();

    lib.addIncludePath(upstream.path("./mir"));

    lib.addCSourceFiles(.{
        .root = upstream.path("./mir"),
        .files = &.{
            "mir.c",
            "mir-gen.c",
            "c2mir/c2mir.c",
        },
        .flags = &.{
            "-fsigned-char",
            "-O3",
            "-DNDEBUG=1",
            "-DMIR_PARALLEL_GEN=1",
            "-fno-sanitize=undefined",
        },
    });

    return lib;
}

pub fn buildRpMalloc(b: *Build, upstream: *Build.Dependency, target: ResolvedTarget, optimize: OptimizeMode) !*Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "rpmalloc",
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();

    lib.addIncludePath(upstream.path("./rpmalloc"));

    lib.addCSourceFiles(.{
        .root = upstream.path("./rpmalloc"),
        .files = &.{"rpmalloc.c"},
        .flags = &.{},
    });

    return lib;
}
