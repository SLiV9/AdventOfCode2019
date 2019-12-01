const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

pub fn main() !void {
    const input = try File.openRead("01/input.txt");
    defer input.close();

    var total_fuel_req: u32 = 0;

    var strm = &input.inStream().stream;
    var buffer: [100]u8 = undefined;
    while (true) {
        var maybe_line = try strm.readUntilDelimiterOrEof(buffer[0..], '\n');
        if (maybe_line) |line| {
            var mass: u32 = try fmt.parseInt(u32, line, 10);
            var fuel: u32 = (mass / 3) - 2;
            std.debug.warn("{} => mass: {}, fuel: {}\n", line, mass, fuel);
            total_fuel_req += fuel;
        } else {
            break;
        }
    }

    std.debug.warn("\nTotal fuel requirement: {}\n", total_fuel_req);
}
