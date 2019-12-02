const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

fn load_program(program: *[1000]u32) !usize {
    const input = try File.openRead("02/input.txt");
    defer input.close();

    const strm = &input.inStream().stream;
    var buffer: [100]u8 = undefined;
    var pos: usize = 0;
    while (true) {
        var mb_str = try strm.readUntilDelimiterOrEof(buffer[0..], ',');
        if (mb_str) |str| {
            const trimmed = std.mem.trim(u8, str, "\r\n ");
            const opcode: u32 = try fmt.parseInt(u32, trimmed, 10);
            program[pos] = opcode;
            pos += 1;
        } else {
            break;
        }
    }

    return pos;
}

fn print_program(program: []u32) void {
    var pos: usize = 0;
    while (pos < program.len) {
        std.debug.warn("[{}] = {}\n", pos, program[pos]);
        pos += 1;
    }
}

pub fn main() !void {
    var program = [_]u32{0} ** 1000;
    const len: usize = try load_program(&program);

    program[1] = 12;
    program[2] = 02;

    print_program(program[0..len]);

    std.debug.warn("\nCode in position 0: {}\n", program[0]);
}
