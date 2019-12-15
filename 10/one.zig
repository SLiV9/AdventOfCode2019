const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const MAX_ROWS = 100;
const MAX_COLS = 100;
const MAX_LEN = MAX_ROWS * MAX_COLS;

const Rock = struct {
    x: i8,
    y: i8,
};

fn load(fname: []const u8, list: *[MAX_LEN]Rock, w: *i8, h: *i8) ![]Rock {
    const input = try File.openRead(fname);
    defer input.close();

    std.debug.assert(MAX_ROWS < 0x7F);
    std.debug.assert(MAX_COLS < 0x7F);

    const strm = &input.inStream().stream;
    var buffer: [MAX_COLS]u8 = undefined;
    var row: i8 = 0;
    var len: usize = 0;
    while (row < MAX_ROWS and len < MAX_LEN) {
        var mb_line = try strm.readUntilDelimiterOrEof(buffer[0..], '\n');
        if (mb_line) |line| {
            for (line) |symbol, col| {
                if (parse_cell(symbol)) {
                    list[len] = Rock{ .x = @intCast(i8, col), .y = row };
                    len += 1;
                }
            }
            w.* = @intCast(i8, line.len);
            row += 1;
        } else {
            h.* = @intCast(i8, row);
            return list[0..len];
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

fn is_blocked(from: Rock, to: Rock, walls: []Rock) bool {
    const dx: i16 = to.x - from.x;
    const dy: i16 = to.y - from.y;

    // Precondition: each wall lies strictly between `from` and `to` in display
    // order. This means to check that the wall lies exactly between them, we
    // only need to check that the line from `from` to `to` is parallel to the
    // line from `from` to the wall.
    for (walls) |wall| {
        const ddx = wall.x - from.x;
        const ddy = wall.y - from.y;
        // Checking that the cross product is 0.
        if (dx * ddy == dy * ddx) {
            return true;
        }
    }

    return false;
}

fn solve(rocks: []Rock) usize {
    var scores: [MAX_LEN]u16 = undefined;
    for (rocks) |station, i| {
        scores[i] = 0;
        // As a factor 2 optimization, only look at rocks with a (strictly)
        // lower index and apply their score to both end points.
        for (rocks[0..i]) |rock, j| {
            // As another factor 2-ish optimization, we use the fact that the
            // rocks are sorted in display order and only look at rocks that
            // have an index strictly between the two endpoints.
            // For proof that this works, let's assume three cases:
            //   1. Both end points are on the same row, thus LOS can only be
            //      blocked by rocks in columns between the two endpoints.
            //   2. The end points are one row apart. In this case there cannot
            //      be any LOS-blocking rocks between them, so that's fine.
            //   3. The end points are two or more rows apart. Here LOS can only
            //      be blocked by rocks in rows strictly between them.
            if (!is_blocked(rock, station, rocks[j + 1 .. i])) {
                scores[i] += 1;
                scores[j] += 1;
            }
        }
    }

    var best_score: u16 = 0;
    var best_i: usize = 0;
    for (scores[0..rocks.len]) |score, i| {
        if (score > best_score) {
            best_score = score;
            best_i = i;
        }
    }

    const station = rocks[best_i];
    std.debug.warn("Best is at {},{} with {} other asteroids\n", .{
        station.x,
        station.y,
        best_score,
    });

    return 0;
}

fn print_map(width: i8, height: i8, rocks: []Rock) void {
    var x: i8 = 0;
    var y: i8 = 0;
    for (rocks) |rock| {
        print_dots(width, height, &x, &y, rock.x, rock.y);
        std.debug.warn("#", .{});
        x += 1;
    }
    print_dots(width, height, &x, &y, 0, height);
    std.debug.warn("\n", .{});
}

fn print_dots(width: i8, height: i8, x: *i8, y: *i8, endx: i8, endy: i8) void {
    while (y.* < endy) {
        while (x.* < width) {
            std.debug.warn(".", .{});
            x.* += 1;
        }
        std.debug.warn("\n", .{});
        y.* += 1;
        x.* = 0;
    }
    while (x.* < endx) {
        std.debug.warn(".", .{});
        x.* += 1;
    }
}

fn get_filename(buffer: []u8) ![]u8 {
    std.debug.warn("filename :: ", .{});
    var stdin = &std.io.getStdIn().inStream().stream;
    var mb_str = try stdin.readUntilDelimiterOrEof(buffer, '\n');
    if (mb_str) |str| {
        std.debug.warn("Opening '{}'...\n\n", .{str});
        return str;
    } else unreachable;
}

pub fn main() !void {
    var filename_buffer: [100]u8 = undefined;
    var filename = try get_filename(filename_buffer[0..]);

    var buffer: [MAX_LEN]Rock = undefined;
    var width: i8 = 0;
    var height: i8 = 0;
    const rocks: []Rock = try load(filename, &buffer, &width, &height);

    print_map(width, height, rocks);

    const solution = solve(rocks);

    std.debug.warn("\n", .{});
    std.debug.warn("Solution: {}\n", .{solution});
}
