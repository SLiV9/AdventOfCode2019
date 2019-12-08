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

const ProgramExit = error{Halt};

const Pipe = struct {
    in: []i32,
    out: []i32,
    in_offset: usize = 0,
    out_offset: usize = 0,

    fn get_input(self: *Pipe) !i32 {
        if (self.in_offset < self.in.len) {
            const x = self.in[self.in_offset];
            self.in_offset += 1;
            return x;
        } else {
            std.debug.warn(":: ");
            return try get_userinput();
        }
    }

    fn output(self: *Pipe, value: i32) void {
        if (self.out_offset < self.out.len) {
            self.out[self.out_offset] = value;
            self.out_offset += 1;
        } else {
            std.debug.warn("{}\n", value);
        }
    }
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

fn execute_op(pg: []i32, pos: usize, pipe: *Pipe) !usize {
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
            return pos + 4;
        },
        2 => {
            const x = try get_value(pg, pos, imode, 1);
            const y = try get_value(pg, pos, imode, 2);
            const addr = try get_addr(pg, pos, imode, 3);
            pg[addr] = x * y;
            return pos + 4;
        },
        3 => {
            const input: i32 = try pipe.get_input();
            const addr = try get_addr(pg, pos, imode, 1);
            pg[addr] = input;
            return pos + 2;
        },
        4 => {
            const x = try get_value(pg, pos, imode, 1);
            pipe.output(x);
            return pos + 2;
        },
        5 => {
            const x = try get_value(pg, pos, imode, 1);
            if (x != 0) {
                return try get_iaddr(pg, pos, imode, 2);
            } else {
                return pos + 3;
            }
        },
        6 => {
            const x = try get_value(pg, pos, imode, 1);
            if (x == 0) {
                return try get_iaddr(pg, pos, imode, 2);
            } else {
                return pos + 3;
            }
        },
        7 => {
            const x = try get_value(pg, pos, imode, 1);
            const y = try get_value(pg, pos, imode, 2);
            const addr = try get_addr(pg, pos, imode, 3);
            pg[addr] = if (x < y) 1 else 0;
            return pos + 4;
        },
        8 => {
            const x = try get_value(pg, pos, imode, 1);
            const y = try get_value(pg, pos, imode, 2);
            const addr = try get_addr(pg, pos, imode, 3);
            pg[addr] = if (x == y) 1 else 0;
            return pos + 4;
        },
        99 => {
            return ProgramExit.Halt;
        },
        else => {
            std.debug.warn("Unknown operation {}\n", op);
            return ProgramError.UnknownOpcode;
        },
    }
}

fn get_iaddr(pg: []i32, pos: usize, imode: [MAX_OP_LEN]bool, x: usize) !usize {
    const value = try get_value(pg, pos, imode, x);
    if (value < 0) {
        return ProgramError.NegativeAddress;
    }
    return @intCast(usize, value);
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

fn execute_program(pg: []i32, pipe: *Pipe) !void {
    var pos: usize = 0;
    while (pos < pg.len) {
        pos = execute_op(pg, pos, pipe) catch |err| {
            switch (err) {
                ProgramExit.Halt => return,
                else => return err,
            }
        };
    }
    return ProgramError.InstructionPointerOutOfBounds;
}

fn calculate(program: []i32, amps: []i32) !i32 {
    var memory: [MAX_PG_LEN]i32 = undefined;
    var buffer: [10]i32 = undefined;
    buffer[1] = 0;
    for (amps) |phase, i| {
        buffer[2 * i] = phase;
        const last = (i + 1 < amps.len);
        var pipe = Pipe{
            .in = buffer[2 * i .. 2 * i + 2],
            .out = if (last) buffer[2 * i + 3 .. 2 * i + 4] else buffer[0..0],
        };
        std.mem.copy(i32, memory[0..], program);
        try execute_program(memory[0..program.len], &pipe);
    }
    return buffer[9];
}

fn solve(program: []i32) !i32 {
    var amps = [_]i32{ 4, 3, 2, 1, 0 };
    const value = try calculate(program, amps[0..]);
    return value;
}

pub fn main() !void {
    var program: [MAX_PG_LEN]i32 = undefined;
    const len: usize = try load_program(&program, "07/sample1.txt");

    const solution = try solve(program[0..len]);

    std.debug.warn("\n");
    std.debug.warn("Done.\n");
}
