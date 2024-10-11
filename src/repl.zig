const std = @import("std");
const isocline = @import("isocline");
const known_folders = @import("known-folders");
const lunaro = @import("lunaro");

const path = std.fs.path;

pub fn startRepl(L: *lunaro.State) !void {
    var path_buffer: [500]u8 = undefined;
    var path_fba = std.heap.FixedBufferAllocator.init(&path_buffer);
    var abspath_buffer: [500]u8 = undefined;
    var abspath_fba = std.heap.FixedBufferAllocator.init(&abspath_buffer);
    const path_allocator = path_fba.allocator();
    const abspath_allocator = abspath_fba.allocator();

    const home_path = try known_folders.getPath(path_allocator, .home);
    const hist_path = try path.joinZ(abspath_allocator, &[_][]const u8{ home_path.?, ".kue_history" });
    isocline.setHistory(hist_path, -1);

    while (true) {
        if (isocline.readline(null)) |line| {
            if (L.loadstring(std.mem.span(line), "@stdin", .text) != .ok) {
                try handleError(L);
                continue;
            }
            if (L.pcall(0, 0, 0) != .ok) try handleError(L);
        } else break;
    }
}

fn handleError(L: *lunaro.State) !void {
    var buff: [255]u8 = undefined;
    const msg = L.tostring(-1) orelse try std.fmt.bufPrintZ(&buff, "<error message is a {s}>", .{L.typenameof(-1)});

    L.traceback(L, msg, 1);
    const stderr = std.io.getStdErr().writer();
    _ = .{
        try stderr.write(L.tostring(-1).?),
        try stderr.write("\n"),
    };
}
