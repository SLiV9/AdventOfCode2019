const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const MAX_COLS = 1000;
const MAX_ROWS = 1000;

fn load(fname: []const u8, data: *[MAX_ROWS][MAX_COLS]bool, result: *[MAX_ROWS][]bool) ![][]bool {
    const input = try File.openRead(fname);
    defer input.close();

    const strm = &input.inStream().stream;
    var buffer: [MAX_COLS]u8 = undefined;
    var n_rows: usize = 0;
    while (n_rows < MAX_ROWS) {
        var mb_line = try strm.readUntilDelimiterOrEof(buffer[0..], '\n');
        if (mb_line) |line| {
            for (line) |x, i| {
                data[n_rows][i] = parse_cell(x);
            }
            result[n_rows] = data[n_rows][0..line.len];
            n_rows += 1;
        } else {
            return result[0..n_rows];
        }
    }
    unreachable;
}

fn parse_cell(x: u8) bool {
    switch (x) {
        '.' => return false,
        '#' => return true,
        else => unreachable,
    }
}

fn solve(map: []bool) usize {
    // TODO
    return 0;
}

pub fn main() !void {
    const filename = "10/sample1.txt";

    var databuffer: [MAX_ROWS][MAX_COLS]bool = undefined;
    var resultbuffer: [MAX_ROWS][]bool = undefined;
    const map: [][]bool = try load(filename, &databuffer, &resultbuffer);

    for (map) |row| {
        for (row) |cell| {
            if (cell) {
                std.debug.warn("#", .{});
            } else {
                std.debug.warn(".", .{});
            }
        }
        std.debug.warn("\n", .{});
    }

    const solution = solve(map);

    std.debug.warn("\n", .{});
    std.debug.warn("Solution: {}\n", .{solution});
}
