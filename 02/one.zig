const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

fn load_program(program: *[1000]u32, filename: []const u8) !usize {
    const input = try File.openRead(filename);
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

const ProgramError = error{
    UnknownOpcode,
    OutOfBounds,
    OutOfProgram,
};

fn execute_op(pg: []u32, pos: usize) !bool {
    switch (pg[pos]) {
        1 => {
            try check_op_bounds(pg, pos);
            pg[pg[pos + 3]] = pg[pg[pos + 1]] + pg[pg[pos + 2]];
        },
        2 => {
            try check_op_bounds(pg, pos);
            pg[pg[pos + 3]] = pg[pg[pos + 1]] * pg[pg[pos + 2]];
        },
        99 => {
            return true;
        },
        else => {
            return ProgramError.UnknownOpcode;
        },
    }
    return false;
}

fn check_op_bounds(pg: []u32, pos: usize) !void {
    if (pos + 3 >= pg.len) {
        return ProgramError.OutOfBounds;
    } else if (pg[pos + 1] >= pg.len) {
        return ProgramError.OutOfBounds;
    } else if (pg[pos + 2] >= pg.len) {
        return ProgramError.OutOfBounds;
    } else if (pg[pos + 3] >= pg.len) {
        return ProgramError.OutOfBounds;
    }
}

fn execute_program(pg: []u32) !void {
    var pos: usize = 0;
    while (pos < pg.len) {
        const stop: bool = try execute_op(pg, pos);
        if (stop) {
            return;
        }
        pos += 4;
    }
    return ProgramError.OutOfProgram;
}

pub fn main() !void {
    var program = [_]u32{0} ** 1000;
    const len: usize = try load_program(&program, "02/input-one.txt");

    print_program(program[0..len]);

    try execute_program(program[0..len]);

    std.debug.warn("\n");

    print_program(program[0..len]);

    std.debug.warn("\nCode in position 0: {}\n", program[0]);
}
