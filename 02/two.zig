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
    const len: usize = try load_program(&program, "02/input.txt");

    var memory: [1000]u32 = undefined;
    var noun: u32 = 0;
    while (noun < 100) {
        var verb: u32 = 0;
        while (verb < 100) {
            memory[0] = program[0];
            memory[1] = noun;
            memory[2] = verb;
            for (program[3..len]) |x, i| {
                memory[i] = x;
            }
            try execute_program(memory[0..len]);
            var result: u32 = memory[0];
            if (result == 19690720) {
                std.debug.warn("\nFound {} {}\n", noun, verb);
                return;
            }
            verb += 1;
        }
        noun += 1;
    }

    std.debug.warn("All posibilities exhausted, no solution found.\n");
}
