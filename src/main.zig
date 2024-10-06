const std = @import("std");
const lunaro = @import("lunaro");

const rpmalloc = @cImport({
    @cInclude("rpmalloc.h");
});

pub fn main() !void {
    _ = rpmalloc.rpmalloc_initialize(0);
    defer rpmalloc.rpmalloc_finalize();

    const L = try lunaro.State.initWithAlloc(allocFn, null);
    // const L = try lunaro.State.init();
    defer L.close();

    L.openlibs();
    _ = L.loadstring(
        \\print("Hello World!")
        \\print(_VERSION)
        \\return "From Lua!"
    , "", .text);

    _ = L.pcall(0, 1, 0);
}

fn allocFn(ud: ?*anyopaque, ptr: ?*anyopaque, osize: usize, nsize: usize) callconv(.C) ?*anyopaque {
    _ = ud;
    _ = osize;

    if (nsize == 0) {
        rpmalloc.rpfree(ptr);
        return null;
    } else if (ptr == null) {
        return rpmalloc.rpmalloc(nsize);
    } else {
        return rpmalloc.rprealloc(ptr, nsize);
    }
}
