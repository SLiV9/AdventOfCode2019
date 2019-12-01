const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

pub fn main() !void {
    const input = try File.openRead("01/input.txt");
    defer input.close();

    var strm = input.inStream().stream;
    var buffer: []u8 = undefined;
    while (strm.readUntilDelimiterOrEof(buffer, '\n')) {
        try stdout.write(buffer);
        try stdout.write("\n");
    }

    std.debug.warn("Done.\n");
}
