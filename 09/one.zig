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
    InputEmpty,
    OutputFull,
};

const ProgramExit = error{Halt};

const Pipe = struct {
    in_buffer: ?[]i32,
    out_buffer: ?[]i32,
    in_offset: usize = 0,
    out_offset: usize = 0,
    in_remaining: usize = 0,
    out_remaining: usize = 0,

    fn get_input(self: *Pipe) !i32 {
        if (self.in_buffer) |in_buffer| {
            if (self.in_remaining > 0) {
                const x = in_buffer[self.in_offset];
                self.in_offset += 1;
                if (self.in_offset == in_buffer.len) {
                    self.in_offset = 0;
                }
                self.in_remaining -= 1;
                return x;
            } else {
                return ProgramError.InputEmpty;
            }
        } else {
            return try get_userinput();
        }
    }

    fn output(self: *Pipe, value: i32) !void {
        if (self.out_buffer) |out_buffer| {
            if (self.out_remaining > 0) {
                out_buffer[self.out_offset] = value;
                self.out_offset += 1;
                if (self.out_offset == out_buffer.len) {
                    self.out_offset = 0;
                }
                self.out_remaining -= 1;
            } else {
                return ProgramError.OutputFull;
            }
        } else {
            std.debug.warn("{}\n", .{value});
        }
    }
};

fn get_userinput() !i32 {
    std.debug.warn(":: ", .{});
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
            try pipe.output(x);
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
            std.debug.warn("Unknown operation {}\n", .{op});
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

fn execute_program(pg: []i32, startpos: usize, pipe: *Pipe) !usize {
    var pos: usize = startpos;
    while (pos < pg.len) {
        pos = execute_op(pg, pos, pipe) catch |err| {
            switch (err) {
                ProgramExit.Halt => return pos,
                else => return err,
            }
        };
    }
    return ProgramError.InstructionPointerOutOfBounds;
}

pub fn main() !void {
    var program: [MAX_PG_LEN]i32 = undefined;
    const len: usize = try load_program(&program, "05/input.txt");

    var io = Pipe{
        .in_buffer = null,
        .out_buffer = null,
    };
    _ = try execute_program(program[0..len], 0, &io);

    std.debug.warn("\n", .{});
    std.debug.warn("Done.\n", .{});
}
