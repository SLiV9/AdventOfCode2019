const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

pub fn main() !void {
    const input = try File.openRead("01/input.txt");
    defer input.close();

    var strm = &input.inStream().stream;
    var buffer: [100]u8 = undefined;
    while (true) {
        var line = try strm.readUntilDelimiterOrEof(buffer[0..], '\n');
        if (line == null) break;
        std.debug.warn("{}\n", line);
    }

    std.debug.warn("Done.\n");
}
