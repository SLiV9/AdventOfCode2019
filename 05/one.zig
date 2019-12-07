const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const MAX_PG_LEN: usize = 1000;
const MAX_OP_LEN: usize = 4;

fn load_program(program: *[MAX_PG_LEN]i32, filename: []const u8) !usize {
    const input = try File.openRead(filename);
    defer input.close();

    const strm = &input.inStream().stream;
    var buffer: [100]u8 = undefined;
    var pos: usize = 0;
    while (true) {
        var mb_str = try strm.readUntilDelimiterOrEof(buffer[0..], ',');
        if (mb_str) |str| {
            const trimmed = std.mem.trim(u8, str, "\r\n ");
            program[pos] = try fmt.parseInt(i32, trimmed, 10);
            pos += 1;
        } else {
            break;
        }
    }

    return pos;
}

const ProgramError = error{
    NegativeOpcode,
    UnknownOpcode,
    NegativeAddress,
    AddressOutOfBounds,
    InstructionOutOfBounds,
    InstructionPointerOutOfBounds,
    ImmediateModeWrite,
    NoUserInput,
};

fn get_userinput() !i32 {
    var stdin = &std.io.getStdIn().inStream().stream;
    var buffer: [100]u8 = undefined;
    var mb_str = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');
    if (mb_str) |str| {
        return try fmt.parseInt(i32, str, 10);
    } else {
        return ProgramError.NoUserInput;
    }
}

fn execute_op(pg: []i32, pos: usize) !usize {
    if (pg[pos] < 0) {
        return ProgramError.NegativeOpcode;
    }
    const op: u32 = @intCast(u32, pg[pos]);
    const opcode = op % 100;
    const imode = [MAX_OP_LEN]bool{
        undefined,
        ((op / 100) % 10) > 0,
        ((op / 1000) % 10) > 0,
        ((op / 10000) % 10) > 0,
    };

    switch (opcode) {
        1 => {
            const x = try get_value(pg, pos, imode, 1);
            const y = try get_value(pg, pos, imode, 2);
            const addr = try get_addr(pg, pos, imode, 3);
            pg[addr] = x + y;
            return 4;
        },
        2 => {
            const x = try get_value(pg, pos, imode, 1);
            const y = try get_value(pg, pos, imode, 2);
            const addr = try get_addr(pg, pos, imode, 3);
            pg[addr] = x * y;
            return 4;
        },
        3 => {
            std.debug.warn(":: ");
            const input: i32 = try get_userinput();
            const addr = try get_addr(pg, pos, imode, 1);
            pg[addr] = input;
            return 2;
        },
        4 => {
            const x = try get_value(pg, pos, imode, 1);
            std.debug.warn("{}\n", x);
            return 2;
        },
        99 => {
            return 0;
        },
        else => {
            return ProgramError.UnknownOpcode;
        },
    }
}

fn get_value(pg: []i32, pos: usize, imode: [MAX_OP_LEN]bool, x: usize) !i32 {
    std.debug.assert(x > 0 and x < MAX_OP_LEN);
    if (pos + x >= pg.len) {
        return ProgramError.InstructionOutOfBounds;
    } else if (imode[x]) {
        return pg[pos + x];
    } else {
        const addr: usize = try get_addr(pg, pos, imode, x);
        return pg[addr];
    }
}

fn get_addr(pg: []i32, pos: usize, imode: [MAX_OP_LEN]bool, x: usize) !usize {
    std.debug.assert(x > 0 and x < MAX_OP_LEN);
    if (pos + x >= pg.len) {
        return ProgramError.InstructionOutOfBounds;
    } else if (pg[pos + x] < 0) {
        return ProgramError.NegativeAddress;
    } else if (imode[x]) {
        return ProgramError.ImmediateModeWrite;
    }

    const addr: usize = @intCast(usize, pg[pos + x]);
    if (addr >= pg.len) {
        return ProgramError.AddressOutOfBounds;
    }
    return addr;
}

fn execute_program(pg: []i32) !void {
    var pos: usize = 0;
    while (pos < pg.len) {
        const advance = try execute_op(pg, pos);
        if (advance == 0) {
            return;
        }
        pos += advance;
    }
    return ProgramError.InstructionPointerOutOfBounds;
}

pub fn main() !void {
    var program: [MAX_PG_LEN]i32 = undefined;
    const len: usize = try load_program(&program, "05/input.txt");

    try execute_program(program[0..len]);

    std.debug.warn("\n");
    std.debug.warn("Done.\n");
}
