const std = @import("std");
const lunaro = @import("lunaro");
const helpers = @import("../helpers.zig");

const json = std.json;

pub fn open(L: *lunaro.State) c_int {
    L.createtable(0, 3);
    const table = lunaro.Table.init(L, L.gettop());
    defer table.deinit();

    L.pushclosure(decode, 0);
    table.set("decode");

    table.push(L);
    return 1;
}

fn decode(L: *lunaro.State) c_int {
    L.ensuretype(1, .string);
    const str = L.tostring(1).?;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const parsed = json.parseFromSlice(json.Value, allocator, str, .{}) catch |err| blk: {
        _ = gpa.deinit();
        helpers.throwZigError(L, err);
        break :blk json.Parsed(json.Value){};
    };
    defer parsed.deinit();

    internalDecode(L, parsed.value);
    return 1;
}

fn encode(L: *lunaro.State) c_int {
    _ = L;
    return 0;
}

fn internalDecode(L: *lunaro.State, value: json.Value) void {
    switch (value) {
        .null => L.pushnil(),
        .bool => |v| L.pushboolean(v),
        .integer => |v| L.pushinteger(v),
        .float => |v| L.pushnumber(v),
        .number_string => |v| {
            L.pushstring(v);
            const num = L.tonumber(-1);
            L.pop(1);
            L.pushnumber(num);
        },
        .string => |v| L.pushstring(v),
        .array => |v| {
            L.createtable(0, 0);
            for (v.items, 0..) |arr_v, i| {
                internalDecode(L, arr_v);
                L.seti(-2, @intCast(i + 1));
            }
        },
        .object => |v| {
            const keys = v.keys();
            const values = v.values();

            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const allocator = gpa.allocator();

            L.createtable(0, 0);
            for (keys, 0..) |k, i| {
                internalDecode(L, values[i]);
                const t_k = allocator.dupeZ(u8, k) catch |err| blk: {
                    _ = gpa.deinit();
                    helpers.throwZigError(L, err);
                    break :blk "";
                };
                L.setfield(-2, t_k);
                allocator.free(t_k);
            }
        },
    }
}
