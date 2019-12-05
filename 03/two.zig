const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const Move = struct {
    way: u8,
    dis: i32,
};

const Rect = struct {
    way: u8,
    is_vert: bool,
    // Box.
    l: i32,
    r: i32,
    t: i32,
    b: i32,
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

fn reverse(rect: Rect) Rect {
    var result = rect;
    result.way = switch (rect.way) {
        'U' => 'D',
        'L' => 'R',
        'R' => 'L',
        'D' => 'U',
        else => unreachable,
    };
    return result;
}

fn intersect_hv(hh: Rect, vv: Rect) ?i32 {
    if (hh.l < vv.l and vv.r < hh.r and vv.t < hh.t and hh.b < vv.b) {
        const x = vv.l;
        const y = hh.t;
        const dx = if (hh.way == 'R') (x - hh.l) else (hh.r - x);
        const dy = if (vv.way == 'D') (y - vv.t) else (vv.b - y);
        return dx + dy;
    } else {
        return null;
    }
}

fn intersect_ab(aa: Rect, bb: Rect) ?i32 {
    if (!aa.is_vert and bb.is_vert) {
        return intersect_hv(aa, bb);
    } else if (aa.is_vert and !bb.is_vert) {
        return intersect_hv(bb, aa);
    } else {
        // We assume that parallel lines do not cross.
    }

    return null;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var xxx: [10][1000]Move = undefined;
    var yyy: [10][]Move = undefined;
    const snakes = try parse_snakes("03/selfcross.txt", &xxx, &yyy);

    for (snakes) |snake| {
        for (snake) |move| {
            std.debug.warn("{c}{} ", move.way, move.dis);
        }
        std.debug.warn(" ({})\n", snake.len);
    }

    var rect: [10][1000]Rect = undefined;
    var sum_of_lengths: i32 = 0;

    for (snakes) |snake, i| {
        var x: i32 = 0;
        var y: i32 = 0;
        for (snake) |move, t| {
            rect[i][t] = .{
                .way = move.way,
                .is_vert = (move.way == 'U' or move.way == 'D'),
                .l = x,
                .r = x,
                .t = y,
                .b = y,
            };
            switch (move.way) {
                'U' => {
                    y -= move.dis;
                    rect[i][t].t = y;
                },
                'L' => {
                    x -= move.dis;
                    rect[i][t].l = x;
                },
                'R' => {
                    x += move.dis;
                    rect[i][t].r = x;
                },
                'D' => {
                    y += move.dis;
                    rect[i][t].b = y;
                },
                else => unreachable,
            }
            sum_of_lengths += move.dis;
        }
    }

    var basecost: [10][1000]i32 = undefined;

    for (snakes) |snake, i| {
        basecost[i][0] = 0;
        for (snake) |move, t| {
            basecost[i][t + 1] = basecost[i][t] + move.dis;
            for (snake[0..t]) |_, u| {
                if (intersect_ab(rect[i][t], rect[i][u])) |_| {
                    if (intersect_ab(reverse(rect[i][t]), rect[i][u])) |ec| {
                        std.debug.warn("was {}\n", basecost[i][t + 1]);
                        basecost[i][t + 1] = basecost[i][u] + ec;
                        std.debug.warn("now {}\n", basecost[i][t + 1]);
                    } else unreachable;
                }
            }
        }
    }

    var solution: i32 = sum_of_lengths;

    for (snakes) |snake, i| {
        for (snake) |move, t| {
            for (snakes[0..i]) |other, j| {
                for (other) |othermove, u| {
                    if (intersect_ab(rect[i][t], rect[j][u])) |extracost| {
                        var x = basecost[i][t] + basecost[j][u] + extracost;
                        if (x < solution) {
                            solution = x;
                        }
                    }
                }
            }
        }
    }

    std.debug.warn("\n");
    std.debug.assert(solution < sum_of_lengths);
    std.debug.warn("Solution: {}.\n", solution);
}
