const std = @import("std");
const lunaro = @import("lunaro");

pub fn assert(L: *lunaro.State, cond: bool, msg: [:0]const u8, args: anytype) void {
    if (!cond)
        L.raise(msg, args);
}

pub inline fn throwZigError(L: *lunaro.State, err: anyerror) void {
    // var info: lunaro.DebugInfo = undefined;
    // if (L.getinfo("n", &info))
    //     L.raise("function '%s' throws an error '%s'", .{ info.name, @errorName(err) });
    L.raise("function returns an error '%s'", .{@errorName(err)});
}
