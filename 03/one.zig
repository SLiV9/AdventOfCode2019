const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const Move = struct {
    way: u8,
    dis: i32,
};

fn parse_snake(line: []u8, snake: *[1000]Move) ![]Move {
    var len: usize = 0;

    var it = std.mem.tokenize(line, ",");
    while (it.next()) |str| {
        std.debug.assert(len < snake.len);
        snake[len] = Move{
            .way = str[0],
            .dis = try fmt.parseInt(i32, str[1..], 10),
        };
        len += 1;
    }

    return snake[0..len];
}

fn parse_snakes(filename: []const u8, buffer: *[10][1000]Move, snakes: *[10][]Move) ![][]Move {
    const input = try File.openRead(filename);
    defer input.close();

    var len: usize = 0;

    var istrm = &input.inStream().stream;
    var linebuffer: [12000]u8 = undefined;
    while (true) {
        var mb_line = try istrm.readUntilDelimiterOrEof(linebuffer[0..], '\n');
        if (mb_line) |line| {
            std.debug.assert(len < snakes.len);
            std.debug.warn("({})\n", line);
            snakes[len] = try parse_snake(line, &buffer[len]);
            len += 1;
        } else {
            break;
        }
    }
    return snakes[0..len];
}

fn jump_move(move: Move, x: *i32, y: *i32) void {
    switch (move.way) {
        'U' => {
            y.* -= move.dis;
        },
        'L' => {
            x.* -= move.dis;
        },
        'R' => {
            x.* += move.dis;
        },
        'D' => {
            y.* += move.dis;
        },
        else => std.debug.assert(false),
    }
}

fn paint(cell: *u8, color: u8) bool {
    switch (cell.*) {
        ' ' => {
            cell.* = color;
            return false;
        },
        'a'...'z' => {
            std.debug.assert(color >= 'A' and color <= 'Z');
            if (cell.* != color - 'A' + 'a') {
                cell.* = 'X';
                return true;
            } else {
                return false;
            }
        },
        'A'...'Z' => {
            std.debug.assert(color >= 'a' and color <= 'z');
            if (cell.* != color - 'a' + 'A') {
                cell.* = 'X';
                return true;
            } else {
                return false;
            }
        },
        else => {
            std.debug.warn("unknown cell color {c}\n", cell.*);
            std.debug.assert(false);
            return false;
        },
    }
}

fn absdiff(a: u32, b: u32) u32 {
    if (a > b) {
        return a - b;
    } else {
        return b - a;
    }
}

fn check(x: u32, y: u32, cx: u32, cy: u32, solution: *u32) void {
    var dx = absdiff(x, cx);
    var dy = absdiff(y, cy);
    var d = dx + dy;
    if (d < solution.*) {
        solution.* = d;
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var xxx: [10][1000]Move = undefined;
    var yyy: [10][]Move = undefined;
    const snakes = try parse_snakes("03/input.txt", &xxx, &yyy);

    for (snakes) |snake| {
        for (snake) |move| {
            std.debug.warn("{c}{} ", move.way, move.dis);
        }
        std.debug.warn(" ({})\n", snake.len);
    }

    var x0: i32 = 0;
    var x1: i32 = 0;
    var y0: i32 = 0;
    var y1: i32 = 0;

    for (snakes) |snake| {
        var x: i32 = 0;
        var y: i32 = 0;
        for (snake) |move| {
            jump_move(move, &x, &y);
            if (x < x0) {
                x0 = x;
            }
            if (x > x1) {
                x1 = x;
            }
            if (y < y0) {
                y0 = y;
            }
            if (y > y1) {
                y1 = y;
            }
        }
    }

    const cx = @intCast(u32, 1 - x0);
    const cy = @intCast(u32, 1 - y0);
    const w = @intCast(u32, x1 - x0 + 3);
    const h = @intCast(u32, y1 - y0 + 3);

    std.debug.warn("cx = {}, cy = {}, w = {}, h = {}\n", cx, cy, w, h);

    var grid: []u8 = try allocator.alloc(u8, h * w);
    {
        var r: u32 = 0;
        while (r < h) {
            var c: u32 = 0;
            while (c < w) {
                if (r == 0 or r == h - 1 or c == 0 or c == w - 1) {
                    grid[r * w + c] = '.';
                } else if (r == cy and c == cx) {
                    grid[r * w + c] = 'o';
                } else {
                    grid[r * w + c] = ' ';
                }
                c += 1;
            }
            r += 1;
        }
    }

    var solution: u32 = w * h;

    var hcolor: u8 = 'a';
    var vcolor: u8 = 'A';
    for (snakes) |snake| {
        var r: u32 = cy;
        var c: u32 = cx;
        for (snake) |move| {
            switch (move.way) {
                'U' => {
                    var rr = r - @intCast(u16, move.dis);
                    while (r > rr) {
                        r -= 1;
                        var color: u8 = if (r == rr) '+' else vcolor;
                        if (paint(&grid[r * w + c], color)) {
                            check(c, r, cx, cy, &solution);
                        }
                    }
                },
                'L' => {
                    var cc = c - @intCast(u16, move.dis);
                    while (c > cc) {
                        c -= 1;
                        var color: u8 = if (c == cc) '+' else hcolor;
                        if (paint(&grid[r * w + c], color)) {
                            check(c, r, cx, cy, &solution);
                        }
                    }
                },
                'R' => {
                    var cc = c + @intCast(u16, move.dis);
                    while (c < cc) {
                        c += 1;
                        var color: u8 = if (c == cc) '+' else hcolor;
                        if (paint(&grid[r * w + c], color)) {
                            check(c, r, cx, cy, &solution);
                        }
                    }
                },
                'D' => {
                    var rr = r + @intCast(u16, move.dis);
                    while (r < rr) {
                        r += 1;
                        var color: u8 = if (r == rr) '+' else vcolor;
                        if (paint(&grid[r * w + c], color)) {
                            check(c, r, cx, cy, &solution);
                        }
                    }
                },
                else => std.debug.assert(false),
            }
        }
        hcolor += 1;
        vcolor += 1;
    }

    if (w < 300 and h < 200) {
        var r: u32 = 0;
        while (r < h) {
            var c: u32 = 0;
            while (c < w and c < 230) {
                std.debug.warn("{c}", grid[r * w + c]);
                c += 1;
            }
            std.debug.warn("\n");
            r += 1;
        }
    }

    std.debug.warn("\n");
    std.debug.assert(solution < w * h);
    std.debug.warn("Solution: {}.\n", solution);
}
