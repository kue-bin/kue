const std = @import("std");
const lunaro = @import("lunaro");
const helpers = @import("../helpers.zig");

const json = std.json;

const json_array: [*]const u8 = undefined;

pub fn open(L: *lunaro.State) c_int {
    L.createtable(0, 3);
    const table = lunaro.Table.init(L, L.gettop());
    defer table.deinit();

    L.pushclosure(decode, 0);
    table.set("decode");

    L.pushclosure(encode, 0);
    table.set("encode");

    L.pushlightuserdata(&json_array);
    table.set("emptyarray");

    L.pushlightuserdata(@as(?*anyopaque, @ptrFromInt(0)));
    table.set("null");

    table.push(L);
    return 1;
}

fn decode(L: *lunaro.State) c_int {
    L.ensuretype(1, .string);
    const str = L.tostring(1).?;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const parsed = json.parseFromSlice(json.Value, allocator, str, .{}) catch |err| {
        _ = gpa.deinit();
        helpers.throwZigError(L, err);
        unreachable;
    };
    defer parsed.deinit();

    internalDecode(L, parsed.value, allocator) catch |err| {
        _ = gpa.deinit();
        helpers.throwZigError(L, err);
        unreachable;
    };
    return 1;
}

fn encode(L: *lunaro.State) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    const out = list.writer();

    var w = json.writeStream(out, .{});
    defer w.deinit();

    internalEncode(L, 1, @constCast(&w)) catch |err| {
        _ = gpa.deinit();
        w.deinit();
        helpers.throwZigError(L, err);
        unreachable;
    };

    L.pushstring(list.items);
    return 1;
}

fn internalDecode(L: *lunaro.State, value: json.Value, allocator: std.mem.Allocator) !void {
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
            L.createtable(@intCast(v.items.len), 0);
            for (v.items, 0..) |arr_v, i| {
                try internalDecode(L, arr_v, allocator);
                L.seti(-2, @intCast(i + 1));
            }
        },
        .object => |v| {
            const keys = v.keys();
            const values = v.values();

            L.createtable(0, @intCast(keys.len));
            for (keys, 0..) |k, i| {
                try internalDecode(L, values[i], allocator);
                const zero_k = try allocator.dupeZ(u8, k);
                L.setfield(-2, zero_k);
                allocator.free(zero_k);
            }
        },
    }
}

fn internalEncode(L: *lunaro.State, idx: lunaro.Index, w: anytype) !void {
    return switch (L.typeof(idx)) {
        .lightuserdata => blk: {
            const value = L.touserdata([*]const u8, idx);
            if (value == null) {
                try w.write(null);
                break :blk;
            } else if (value == &json_array) {
                try w.beginArray();
                try w.endArray();
                break :blk;
            }
            L.raise("cannot encode a value of light userdata!", .{});
            unreachable;
        },
        .nil, .none => undefined,
        .boolean => try w.write(L.toboolean(idx)),
        .string => try w.write(L.tostring(idx).?),
        .number => {
            const num = L.tonumber(idx);
            if (num == @round(num))
                try w.write(@as(i64, @intFromFloat(@round(num))))
            else
                try w.write(num);
        },
        .table => {
            L.len(idx);
            const len = L.tointeger(-1);
            L.pop(1);
            if (len == 0) {
                try w.beginObject();
                L.pushnil();
                while (L.next(idx)) {
                    const key = L.tostring(-2).?;
                    try w.objectField(key);
                    try internalEncode(L, L.gettop(), w);
                    L.pop(1);
                }
                try w.endObject();
            } else {
                try w.beginArray();
                var i: i64 = 1;
                while (i <= len) {
                    _ = L.geti(idx, i);
                    try internalEncode(L, L.gettop(), w);
                    L.pop(1);
                    i += 1;
                }
                try w.endArray();
            }
        },
        else => {
            L.raise("cannot encode a value of %s!", .{L.typenameof(idx)});
            unreachable;
        },
    };
}
