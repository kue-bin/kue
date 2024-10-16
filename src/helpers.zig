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

pub const Handler = struct {
    handler: fn (ud: ?*anyopaque) void,
    ud: ?*anyopaque,
    L: *lunaro.State,

    pub fn handle(self: Handler, ret: anytype) @TypeOf(ret) {
        return ret catch |err| {
            self.handler(self.ud);
            throwZigError(self.L, err);
            unreachable;
        };
    }
};

pub inline fn handleZigError(L: *lunaro.State, comptime handler: fn (ud: ?*anyopaque) void, ud: ?*anyopaque) Handler {
    return .{ handler, ud, L };
}
