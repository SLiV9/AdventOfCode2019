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
    in_buffer: []i32,
    out_buffer: []i32,
    in_offset: usize,
    out_offset: usize,
    in_remaining: usize,
    out_remaining: usize,

    fn get_input(self: *Pipe) !i32 {
        if (self.in_remaining > 0) {
            const x = self.in_buffer[self.in_offset];
            self.in_offset += 1;
            if (self.in_offset == self.in_buffer.len) {
                self.in_offset = 0;
            }
            self.in_remaining -= 1;
            return x;
        } else {
            return ProgramError.InputEmpty;
        }
    }

    fn output(self: *Pipe, value: i32) !void {
        if (self.out_remaining > 0) {
            self.out_buffer[self.out_offset] = value;
            self.out_offset += 1;
            if (self.out_offset == self.out_buffer.len) {
                self.out_offset = 0;
            }
            self.out_remaining -= 1;
        } else {
            return ProgramError.OutputFull;
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

const N_AMPS = 5;

fn calculate(program: []i32, phases: []i32) !i32 {
    std.debug.assert(phases.len == N_AMPS);

    var memory: [N_AMPS][MAX_PG_LEN]i32 = undefined;
    for (phases) |_, i| {
        std.mem.copy(i32, memory[i][0..], program);
    }

    var buffer: [2 * N_AMPS]i32 = undefined;
    for (phases) |phase, i| {
        buffer[2 * i] = phase;
    }
    buffer[1] = 0;

    var pipes: [N_AMPS]Pipe = undefined;
    for (phases) |_, i| {
        pipes[i] = Pipe{
            .in_buffer = buffer[0..],
            .in_offset = 2 * i,
            .in_remaining = 2,
            .out_buffer = buffer[0..],
            .out_offset = if (i + 1 < phases.len) 2 * i + 3 else 2,
            .out_remaining = 1,
        };
    }

    var ips = [_]usize{0} ** N_AMPS;

    var final = false;
    while (!final) {
        withnext: for (phases) |_, i| {
            var pg = memory[i][0..program.len];

            //for (buffer) |byte| {
            //    std.debug.warn("{} ", byte);
            //}
            //std.debug.warn("// Amp {}, ip = {}, pipe = {}\n", i, ips[i], pipes[i]);

            while (ips[i] < pg.len) {
                ips[i] = execute_op(pg, ips[i], &pipes[i]) catch |err| {
                    switch (err) {
                        ProgramExit.Halt => {
                            final = true;
                            continue :withnext;
                        },
                        ProgramError.InputEmpty => {
                            pipes[i].in_remaining += 1;
                            pipes[i].out_remaining += 1;
                            continue :withnext;
                        },
                        else => return err,
                    }
                };
            }
            return ProgramError.InstructionPointerOutOfBounds;
        }
    }

    const lastpipe = pipes[phases.len - 1];
    const i = @mod(lastpipe.out_offset - 1, lastpipe.out_buffer.len);
    const result = lastpipe.out_buffer[i];

    //for (phases) |phase| {
    //    std.debug.warn("{}", phase);
    //}
    //std.debug.warn(" => ");
    //for (buffer) |byte| {
    //    std.debug.warn("{} ", byte);
    //}
    //std.debug.warn(" => {}\n", lastpipe.out_buffer[i]);

    return result;
}

fn solve(program: []i32) !i32 {
    var phases: [N_AMPS]i32 = undefined;
    for (phases) |_, i| {
        phases[i] = 5 + @intCast(i32, i);
    }

    // Use Heap's algorithm to iterate through the phases.
    var stackstate = [_]usize{0} ** phases.len;

    var best = try calculate(program, phases[0..]);

    var i: usize = 0;
    while (i < phases.len) {
        if (stackstate[i] < i) {
            if (i % 2 == 0) {
                std.mem.swap(i32, &phases[0], &phases[i]);
            } else {
                std.mem.swap(i32, &phases[stackstate[i]], &phases[i]);
            }

            var value = try calculate(program, phases[0..]);
            if (value > best) {
                best = value;
            }

            stackstate[i] += 1;
            i = 0;
        } else {
            stackstate[i] = 0;
            i += 1;
        }
    }

    return best;
}

pub fn main() !void {
    var program: [MAX_PG_LEN]i32 = undefined;
    const len: usize = try load_program(&program, "07/input.txt");

    //if (true) {
    //    var phases = [_]i32{ 9, 8, 7, 6, 5 };
    //    _ = try calculate(program[0..len], phases[0..]);
    //    return;
    //}

    const solution = try solve(program[0..len]);

    std.debug.warn("\n");
    std.debug.warn("Solution: {}\n", solution);
}
