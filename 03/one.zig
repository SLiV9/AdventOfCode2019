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
    const snakes = try parse_snakes("03/sample1.txt", &xxx, &yyy);

    for (snakes) |snake| {
        for (snake) |move| {
            std.debug.warn("{c}{} ", move.way, move.dis);
        }
        std.debug.warn(" ({})\n", snake.len);
    }

    var hori_x0s: [10][1000]i32 = undefined;
    var hori_x1s: [10][1000]i32 = undefined;
    var hori_ys: [10][1000]i32 = undefined;
    var hori_len: [10]usize = undefined;
    var vert_y0s: [10][1000]i32 = undefined;
    var vert_y1s: [10][1000]i32 = undefined;
    var vert_xs: [10][1000]i32 = undefined;
    var vert_len: [10]usize = undefined;

    var x0: i32 = 0;
    var x1: i32 = 0;
    var y0: i32 = 0;
    var y1: i32 = 0;

    for (snakes) |snake, i| {
        var x: i32 = 0;
        var y: i32 = 0;
        for (snake) |move| {
            switch (move.way) {
                'U' => {
                    vert_xs[i][vert_len[i]] = x;
                    vert_y1s[i][vert_len[i]] = y;
                    y -= move.dis;
                    vert_y0s[i][vert_len[i]] = y;
                    vert_len[i] += 1;
                    if (y < y0) {
                        y0 = y;
                    }
                },
                'L' => {
                    hori_ys[i][hori_len[i]] = y;
                    hori_x1s[i][hori_len[i]] = x;
                    x -= move.dis;
                    hori_x0s[i][hori_len[i]] = x;
                    hori_len[i] += 1;
                    if (x < x0) {
                        x0 = x;
                    }
                },
                'R' => {
                    hori_ys[i][hori_len[i]] = y;
                    hori_x0s[i][hori_len[i]] = x;
                    x += move.dis;
                    hori_x1s[i][hori_len[i]] = x;
                    hori_len[i] += 1;
                    if (x > x1) {
                        x1 = x;
                    }
                },
                'D' => {
                    vert_xs[i][vert_len[i]] = x;
                    vert_y0s[i][vert_len[i]] = y;
                    y += move.dis;
                    vert_y1s[i][vert_len[i]] = y;
                    vert_len[i] += 1;
                    if (y > y1) {
                        y1 = y;
                    }
                },
                else => std.debug.assert(false),
            }
        }
    }

    const cx = @intCast(u32, 1 - x0);
    const cy = @intCast(u32, 1 - y0);
    const w = @intCast(u32, x1 - x0 + 3);
    const h = @intCast(u32, y1 - y0 + 3);

    std.debug.warn("cx = {}, cy = {}, w = {}, h = {}\n", cx, cy, w, h);

    var prediction: u32 = w * h - 1;

    // TODO prediction

    std.debug.warn("\n");
    std.debug.assert(prediction < w * h);
    std.debug.warn("Prediction: {}.\n", prediction);

    if (w > 300 or h > 200) {
        return;
    } else {
        std.debug.warn("\n");
    }

    // Use the old method to confirm the result.
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

    {
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
    std.debug.assert(solution < prediction);
    std.debug.warn("Solution: {}.\n", solution);
}
