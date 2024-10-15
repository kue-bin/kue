// const std = @import("std");
// const lunaro = @import("lunaro");
// // const utils = @import("utilities.zig");

// pub fn open(L: *lunaro.State) c_int {
//     return searcherLua(L);
// }

// fn searcherLua(L: *lunaro.State) c_int {
//     L.ensuretype(1, .string);
//     const module = L.tostring(1).?;
//     if (std.mem.startsWith(u8, module, "./") or std.mem.startsWith(u8, module, "../")) {
//         std.debug.print("test", .{});
//     }
//     return 0;
// }
