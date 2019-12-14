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
    ImmediateModeWrite,
    UnknownMode,
    NoUserInput,
    InputEmpty,
    OutputFull,
    OutOfHeapSpace,
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

fn parse_mode(x: u32) !u2 {
    if (x < 3) {
        return @intCast(u2, x);
    } else {
        return ProgramError.UnknownMode;
    }
}

const Computer = struct {
    program_memory: []i64,
    instr_pos: usize,
    rel_base: usize,
    heap_len: usize,
    heap_addresses: []usize,
    heap_values: []i64,
    pipe: *Pipe,

    fn retrieve(self: *Computer, addr: usize) !i64 {
        if (addr < self.program_memory.len) {
            return self.program_memory[addr];
        } else {
            const index = try self.get_heap_index(addr);
            return self.heap_values[index];
        }
    }

    fn store(self: *Computer, addr: usize, value: i64) !void {
        if (addr < self.program_memory.len) {
            self.program_memory[addr] = value;
        } else {
            const index = try self.get_heap_index(addr);
            self.heap_values[index] = value;
        }
    }

    fn get_heap_index(self: *Computer, addr: usize) !usize {
        for (self.heap_addresses[0..self.heap_len]) |a, i| {
            if (addr == a) {
                return i;
            }
        }

        if (self.heap_len < self.heap_addresses.len) {
            self.heap_len += 1;
            self.heap_addresses[self.heap_len - 1] = addr;
            self.heap_values[self.heap_len - 1] = 0;
            return self.heap_len - 1;
        } else {
            return ProgramError.OutOfHeapSpace;
        }
    }

    fn execute_op(self: *Computer) !usize {
        const instr = try self.retrieve(self.instr_pos);
        if (instr < 0) {
            return ProgramError.NegativeOpcode;
        }
        const op: u32 = @intCast(u32, instr);
        const opcode = op % 100;
        const mode = [MAX_OP_LEN]u2{
            undefined,
            try parse_mode((op / 100) % 10),
            try parse_mode((op / 1000) % 10),
            try parse_mode((op / 10000) % 10),
        };

        switch (opcode) {
            1 => {
                const x = try self.get_value(mode, 1);
                const y = try self.get_value(mode, 2);
                const addr = try self.get_write_addr(mode, 3);
                try self.store(addr, x + y);
                return self.instr_pos + 4;
            },
            2 => {
                const x = try self.get_value(mode, 1);
                const y = try self.get_value(mode, 2);
                const addr = try self.get_write_addr(mode, 3);
                try self.store(addr, x * y);
                return self.instr_pos + 4;
            },
            3 => {
                const input: i64 = try self.pipe.get_input();
                const addr = try self.get_write_addr(mode, 1);
                try self.store(addr, input);
                return self.instr_pos + 2;
            },
            4 => {
                const x = try self.get_value(mode, 1);
                try self.pipe.output(x);
                return self.instr_pos + 2;
            },
            5 => {
                const x = try self.get_value(mode, 1);
                if (x != 0) {
                    return try self.get_jump_addr(mode, 2);
                } else {
                    return self.instr_pos + 3;
                }
            },
            6 => {
                const x = try self.get_value(mode, 1);
                if (x == 0) {
                    return try self.get_jump_addr(mode, 2);
                } else {
                    return self.instr_pos + 3;
                }
            },
            7 => {
                const x = try self.get_value(mode, 1);
                const y = try self.get_value(mode, 2);
                const addr = try self.get_write_addr(mode, 3);
                try self.store(addr, if (x < y) 1 else 0);
                return self.instr_pos + 4;
            },
            8 => {
                const x = try self.get_value(mode, 1);
                const y = try self.get_value(mode, 2);
                const addr = try self.get_write_addr(mode, 3);
                try self.store(addr, if (x == y) 1 else 0);
                return self.instr_pos + 4;
            },
            9 => {
                const x = try self.get_value(mode, 1);
                const r = @intCast(i64, self.rel_base);
                std.debug.assert(r + x >= 0);
                self.rel_base = @intCast(usize, r + x);
                return self.instr_pos + 2;
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

    fn get_jump_addr(self: *Computer, mode: [MAX_OP_LEN]u2, x: usize) !usize {
        const value = try self.get_value(mode, x);
        if (value < 0) {
            return ProgramError.NegativeAddress;
        }
        return @intCast(usize, value);
    }

    fn get_value(self: *Computer, mode: [MAX_OP_LEN]u2, x: usize) !i64 {
        const value = try self.retrieve(self.instr_pos + x);

        std.debug.assert(x > 0 and x < mode.len);
        switch (mode[x]) {
            0 => {
                const addr = try self.get_absolute_addr(value);
                return try self.retrieve(addr);
            },
            1 => {
                return value;
            },
            2 => {
                const addr = try self.get_relative_addr(value);
                return try self.retrieve(addr);
            },
            else => unreachable,
        }
    }

    fn get_write_addr(self: *Computer, mode: [MAX_OP_LEN]u2, x: usize) !usize {
        const offset = try self.retrieve(self.instr_pos + x);

        std.debug.assert(x > 0 and x < mode.len);
        switch (mode[x]) {
            0 => {
                return try self.get_absolute_addr(offset);
            },
            1 => {
                return ProgramError.ImmediateModeWrite;
            },
            2 => {
                return try self.get_relative_addr(offset);
            },
            else => unreachable,
        }
    }

    fn get_absolute_addr(self: *Computer, offset: i64) !usize {
        if (offset < 0) {
            return ProgramError.NegativeAddress;
        }
        const addr: usize = @intCast(usize, offset);
        return addr;
    }

    fn get_relative_addr(self: *Computer, offset: i64) !usize {
        const base = @intCast(i64, self.rel_base);
        if (base + offset < 0) {
            return ProgramError.NegativeAddress;
        }
        const addr: usize = @intCast(usize, base + offset);
        return addr;
    }

    fn execute_program(self: *Computer) !usize {
        while (true) {
            self.instr_pos = self.execute_op() catch |err| {
                switch (err) {
                    ProgramExit.Halt => return self.instr_pos,
                    else => return err,
                }
            };
        }
    }

    fn debug_print(self: *Computer) void {
        std.debug.warn("\n{}\n", .{
            self,
        });
        for (self.program_memory) |value, addr| {
            if (addr == self.instr_pos) std.debug.warn("I@ ", .{});
            std.debug.warn("{}: {}, ", .{ addr, value });
        }
        for (self.heap_values[0..self.heap_len]) |value, i| {
            const addr = self.heap_addresses[i];
            if (addr == self.instr_pos) std.debug.warn("I@ ", .{});
            std.debug.warn("{}: {}, ", .{ addr, value });
        }
        std.debug.warn("\n\n", .{});
    }
};

pub fn main() !void {
    var program: [MAX_PG_LEN]i64 = undefined;
    const len: usize = try load_program(&program, "09/input.txt");

    var io = Pipe{
        .in_buffer = null,
        .out_buffer = null,
    };
    var heap_addresses: [MAX_HEAP_LEN]usize = undefined;
    var heap_values: [MAX_HEAP_LEN]i64 = undefined;
    var computer = Computer{
        .program_memory = program[0..len],
        .instr_pos = 0,
        .rel_base = 0,
        .heap_len = 0,
        .heap_addresses = heap_addresses[0..],
        .heap_values = heap_values[0..],
        .pipe = &io,
    };
    _ = try computer.execute_program();

    std.debug.warn("\n", .{});
    std.debug.warn("Done.\n", .{});
}
