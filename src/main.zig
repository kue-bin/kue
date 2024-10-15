const std = @import("std");
const lunaro = @import("lunaro");
const rpmalloc = @cImport({
    @cInclude("rpmalloc.h");
});

const repl = @import("repl.zig");
const std_json = @import("std/json.zig");

pub fn main() !u8 {
    _ = rpmalloc.rpmalloc_initialize();
    defer rpmalloc.rpmalloc_finalize();

    const L = try lunaro.State.initWithAlloc(allocFn, null);
    defer L.close();

    L.openlibs();

    L.pushclosure(mainChunk, 0);
    const status = L.pcall(0, 1, 0);
    _ = status;
    // const result = L.toboolean(-1);
    // try report(L, status);

    // return if (result and status == .ok) 0 else 1;
    return 0;
}

fn mainChunk(L: *lunaro.State) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    _ = std_json.open(L);
    L.setglobal("json");

    if (std.io.getStdIn().isTty()) {
        try repl.startRepl(L);
    }
}

fn report(L: *lunaro.State, status: lunaro.ThreadStatus) !void {
    if (status != .ok) {
        const stderr = std.io.getStdErr().writer();
        const msg = L.tostring(-1);
        _ = .{
            try stderr.write(msg.?),
        };
        L.pop(1);
    }
}

fn allocFn(ud: ?*anyopaque, ptr: ?*anyopaque, osize: usize, nsize: usize) callconv(.C) ?*anyopaque {
    _ = ud;

    if (nsize == 0) {
        rpmalloc.rpfree(ptr);
        return null;
    } else return rpmalloc.rpaligned_realloc(ptr, 16, nsize, osize, 0);
}
