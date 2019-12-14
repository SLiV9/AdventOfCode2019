const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const MAX_PG_LEN: usize = 1000;
const MAX_OP_LEN: usize = 4;
const MAX_HEAP_LEN: usize = MAX_PG_LEN;

fn load_program(program: *[MAX_PG_LEN]i64, filename: []const u8) !usize {
    const input = try File.openRead(filename);
    defer input.close();

    const strm = &input.inStream().stream;
    var buffer: [100]u8 = undefined;
    var pos: usize = 0;
    while (true) {
        var mb_str = try strm.readUntilDelimiterOrEof(buffer[0..], ',');
        if (mb_str) |str| {
            const trimmed = std.mem.trim(u8, str, "\r\n ");
            program[pos] = try fmt.parseInt(i64, trimmed, 10);
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
    in_buffer: ?[]i64,
    out_buffer: ?[]i64,
    in_offset: usize = 0,
    out_offset: usize = 0,
    in_remaining: usize = 0,
    out_remaining: usize = 0,

    fn get_input(self: *Pipe) !i64 {
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

    fn output(self: *Pipe, value: i64) !void {
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

fn get_userinput() !i64 {
    std.debug.warn(":: ", .{});
    var stdin = &std.io.getStdIn().inStream().stream;
    var buffer: [100]u8 = undefined;
    var mb_str = try stdin.readUntilDelimiterOrEof(buffer[0..], '\n');
    if (mb_str) |str| {
        return try fmt.parseInt(i64, str, 10);
    } else {
        return ProgramError.NoUserInput;
    }
}

const Computer = struct {
    program: []i64,
    instr_pos: usize,
    heap_len: usize,
    heap_addresses: []usize,
    heap_values: []i64,
    pipe: *Pipe,

    fn execute_op(self: *Computer) !usize {
        if (self.program[self.instr_pos] < 0) {
            return ProgramError.NegativeOpcode;
        }
        const op: u32 = @intCast(u32, self.program[self.instr_pos]);
        const opcode = op % 100;
        const imode = [MAX_OP_LEN]bool{
            undefined,
            ((op / 100) % 10) > 0,
            ((op / 1000) % 10) > 0,
            ((op / 10000) % 10) > 0,
        };

        switch (opcode) {
            1 => {
                const x = try self.get_value(imode, 1);
                const y = try self.get_value(imode, 2);
                const addr = try self.get_addr(imode, 3);
                self.program[addr] = x + y;
                return self.instr_pos + 4;
            },
            2 => {
                const x = try self.get_value(imode, 1);
                const y = try self.get_value(imode, 2);
                const addr = try self.get_addr(imode, 3);
                self.program[addr] = x * y;
                return self.instr_pos + 4;
            },
            3 => {
                const input: i64 = try self.pipe.get_input();
                const addr = try self.get_addr(imode, 1);
                self.program[addr] = input;
                return self.instr_pos + 2;
            },
            4 => {
                const x = try self.get_value(imode, 1);
                try self.pipe.output(x);
                return self.instr_pos + 2;
            },
            5 => {
                const x = try self.get_value(imode, 1);
                if (x != 0) {
                    return try self.get_iaddr(imode, 2);
                } else {
                    return self.instr_pos + 3;
                }
            },
            6 => {
                const x = try self.get_value(imode, 1);
                if (x == 0) {
                    return try self.get_iaddr(imode, 2);
                } else {
                    return self.instr_pos + 3;
                }
            },
            7 => {
                const x = try self.get_value(imode, 1);
                const y = try self.get_value(imode, 2);
                const addr = try self.get_addr(imode, 3);
                self.program[addr] = if (x < y) 1 else 0;
                return self.instr_pos + 4;
            },
            8 => {
                const x = try self.get_value(imode, 1);
                const y = try self.get_value(imode, 2);
                const addr = try self.get_addr(imode, 3);
                self.program[addr] = if (x == y) 1 else 0;
                return self.instr_pos + 4;
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

    fn get_iaddr(self: *Computer, imode: [MAX_OP_LEN]bool, x: usize) !usize {
        const value = try self.get_value(imode, x);
        if (value < 0) {
            return ProgramError.NegativeAddress;
        }
        return @intCast(usize, value);
    }

    fn get_value(self: *Computer, imode: [MAX_OP_LEN]bool, x: usize) !i64 {
        std.debug.assert(x > 0 and x < MAX_OP_LEN);
        if (self.instr_pos + x >= self.program.len) {
            return ProgramError.InstructionOutOfBounds;
        } else if (imode[x]) {
            return self.program[self.instr_pos + x];
        } else {
            const addr: usize = try self.get_addr(imode, x);
            return self.program[addr];
        }
    }

    fn get_addr(self: *Computer, imode: [MAX_OP_LEN]bool, x: usize) !usize {
        std.debug.assert(x > 0 and x < MAX_OP_LEN);
        if (self.instr_pos + x >= self.program.len) {
            return ProgramError.InstructionOutOfBounds;
        } else if (self.program[self.instr_pos + x] < 0) {
            return ProgramError.NegativeAddress;
        } else if (imode[x]) {
            return ProgramError.ImmediateModeWrite;
        }

        const addr: usize = @intCast(usize, self.program[self.instr_pos + x]);
        if (addr >= self.program.len) {
            return ProgramError.AddressOutOfBounds;
        }
        return addr;
    }

    fn execute_program(self: *Computer) !usize {
        while (self.instr_pos < self.program.len) {
            self.instr_pos = self.execute_op() catch |err| {
                switch (err) {
                    ProgramExit.Halt => return self.instr_pos,
                    else => return err,
                }
            };
        }
        return ProgramError.InstructionPointerOutOfBounds;
    }
};

pub fn main() !void {
    var program: [MAX_PG_LEN]i64 = undefined;
    const len: usize = try load_program(&program, "05/input.txt");

    var io = Pipe{
        .in_buffer = null,
        .out_buffer = null,
    };
    var heap_addresses: [MAX_HEAP_LEN]usize = undefined;
    var heap_values: [MAX_HEAP_LEN]i64 = undefined;
    var computer = Computer{
        .program = program[0..len],
        .instr_pos = 0,
        .heap_len = 0,
        .heap_addresses = heap_addresses[0..],
        .heap_values = heap_values[0..],
        .pipe = &io,
    };
    _ = try computer.execute_program();

    std.debug.warn("\n", .{});
    std.debug.warn("Done.\n", .{});
}
