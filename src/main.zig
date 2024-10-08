const std = @import("std");
const lunaro = @import("lunaro");
const rpmalloc = @cImport({
    @cInclude("rpmalloc.h");
});

const repl = @import("repl.zig");

pub fn main() !void {
    _ = rpmalloc.rpmalloc_initialize();
    defer rpmalloc.rpmalloc_finalize();

    const L = try lunaro.State.initWithAlloc(allocFn, null);
    defer L.close();

    L.openlibs();

    try repl.startRepl(L);
}

fn allocFn(ud: ?*anyopaque, ptr: ?*anyopaque, osize: usize, nsize: usize) callconv(.C) ?*anyopaque {
    _ = ud;

    if (nsize == 0) {
        rpmalloc.rpfree(ptr);
        return null;
    } else return rpmalloc.rpaligned_realloc(ptr, 16, nsize, osize, 0);
}
