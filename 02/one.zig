const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

pub fn main() !void {
    const input = try File.openRead("02/input-one.txt");
    defer input.close();

    var total_fuel_req: u32 = 0;

    var program = [_]u32{0} ** 1000;

    var istrm = &input.inStream().stream;
    var linebuffer: [12000]u8 = undefined;
    var pos: usize = 0;
    while (true) {
        var mb_line = try istrm.readUntilDelimiterOrEof(linebuffer[0..], '\n');
        if (mb_line) |line| {
            std.debug.warn("({})\n", line);
            var sistrm = std.io.SliceInStream.init(line);
            var strm = sistrm.stream;
            var buffer: [100]u8 = undefined;
            while (true) {
                var mb_str = try strm.readUntilDelimiterOrEof(buffer[0..], ',');
                if (mb_str) |str| {
                    std.debug.warn("[{}]\n", str);
                    var opcode: u32 = try fmt.parseInt(u32, str, 10);
                    std.debug.warn("{} => opcode: {}\n", str, opcode);
                    program[pos] = opcode;
                    pos += 1;
                } else {
                    break;
                }
            }
        } else {
            break;
        }
    }

    const len: usize = pos;

    std.debug.warn("\nCode in position 0: {}\n", program[0]);
}
