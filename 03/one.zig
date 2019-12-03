const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

pub fn main() !void {
    const input = try File.openRead("03/sample1.txt");
    defer input.close();

    var total_fuel_req: u32 = 0;

    var program = [_]u32{0} ** 1000;

    var istrm = &input.inStream().stream;
    var linebuffer: [1000]u8 = undefined;
    var pos: usize = 0;
    while (true) {
        var mb_line = try istrm.readUntilDelimiterOrEof(linebuffer[0..], '\n');
        if (mb_line) |line| {
            std.debug.warn("({})\n", line);
            var it = std.mem.tokenize(line, ",");
            while (it.next()) |str| {
                std.debug.warn("{}\n", str);
            }
        } else {
            break;
        }
    }

    const len: usize = pos;

    std.debug.warn("\nDone.\n");
}
