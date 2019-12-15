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

const AngledRock = struct {
    rock: Rock,
    dx: i8,
    dy: i8,
};

// For rocks in the first segment, with angles less than 90 degrees,
// we sort the rocks by the non-steepness of their slope.
//
//   a < b  iff  ady/adx > bdy/bdx  (ignoring div by zero)
//          iff  adx/ady < bdx/bdy  (no div by zero because dy > 0)
//          iff  adx*bdy < bdx*bdy  (it is first iff dx is zero)
//
fn comparison_0(a: AngledRock, b: AngledRock) bool {
    return (a.dx * b.dy) < (b.dx * a.dy);
}

// For rocks in the second segment, we rotate the slopes 90 degrees
// counter-clockwise and sort the rocks by the non-steepness of those
// slopeself.
//
//   a < b  iff  adx/-ady > bdx/-bdy  (ignoring div by zero)
//          iff  -ady/adx < -bdy/bdx  (no div by zero because dx > 0)
//          iff  -ady*bdx < -bdy*adx  (it is first iff dy is zero)
//
fn comparison_1(a: AngledRock, b: AngledRock) bool {
    return (-a.dy * b.dx) < (-b.dy * a.dx);
}

// For rocks in the third segment, we invert the slopes and then use
// the same ordering as in the first segment.
//
//   a < b  iff  -adx*-bdy < -bdx*-bdy  (all d's inverted)
//          iff   adx* bdy >  bdx* bdy  (it is first iff dx is zero)
//
fn comparison_2(a: AngledRock, b: AngledRock) bool {
    return (a.dx * b.dy) > (b.dx * a.dy);
}

// For rocks in the last segment, with angles of 270 degrees or more,
// we sort by the steepness of their horizontally inverted slope.
//
//   a < b  iff  ady/-adx < bdy/-bdx  (no div by zero because dx > 0)
//          iff  ady*-bdx < bdy*-adx
//
fn comparison_3(a: AngledRock, b: AngledRock) bool {
    return (a.dy * -b.dx) < (b.dy * -a.dx);
}

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
        '#', 'X' => return true,
        else => unreachable,
    }
}

fn count_blockers(from: Rock, to: Rock, walls: []Rock) u16 {
    const dx: i16 = to.x - from.x;
    const dy: i16 = to.y - from.y;

    // Precondition: each wall lies strictly between `from` and `to` in display
    // order. This means to check that the wall lies exactly between them, we
    // only need to check that the line from `from` to `to` is parallel to the
    // line from `from` to the wall.
    var n_blockers: u16 = 0;
    for (walls) |wall| {
        const ddx = wall.x - from.x;
        const ddy = wall.y - from.y;
        // Checking that the cross product is 0.
        if (dx * ddy == dy * ddx) {
            n_blockers += 1;
        }
    }

    return n_blockers;
}

fn solve(rocks: []Rock) void {
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
            if (count_blockers(rock, station, rocks[j + 1 .. i]) == 0) {
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

    var ranks: [MAX_LEN]u16 = undefined;
    var rank_barplot: [MAX_LEN]u16 = undefined;
    var max_rank: u16 = 0;
    rank_barplot[0] = 0;

    const station_i = best_i;
    for (rocks) |rock, j| {
        if (j == station_i) continue;
        const i = station_i;
        const walls = if (j < i) rocks[j + 1 .. i] else rocks[i + 1 .. j];
        const rank = count_blockers(rock, station, walls);
        ranks[j] = rank;
        while (max_rank < rank) {
            rank_barplot[max_rank] = 0;
            max_rank += 1;
        }
        rank_barplot[rank] += 1;
    }

    var destroyed: u16 = 0;
    var crucial_rank = determine: {
        for (rank_barplot) |amount, rank| {
            if (destroyed + amount >= 200) {
                break :determine rank;
            }
            destroyed += amount;
        }
        unreachable;
    };

    // Because the rocks are sorted in display order, we know that the rocks
    // with indices higher than the station are exactly those rocks with an
    // angle between 90 degrees inclusive and 270 degrees exclusive.
    // We should split the rocks with lower indices into those with an angle
    // less than 90 degrees and those with an angle of 270 degrees or greater;
    // we can do this solely based on the x-coordinate.
    // We can also do the same for the rocks with higher indices by splitting
    // then into those with an angle less than 180 and those with 180 or more.
    var candidate_buffer: [4][MAX_LEN]AngledRock = undefined;
    var segment_len = [_]u16{0} ** 4;
    for (rocks) |rock, j| {
        var segment: usize = 0;
        if (j < station_i and ranks[j] == crucial_rank) {
            if (rock.x < station.x) {
                segment = 0;
            } else {
                segment = 3;
            }
        } else if (j > station_i and ranks[j] == crucial_rank) {
            if (rock.x > station.x) {
                segment = 1;
            } else {
                segment = 2;
            }
        } else {
            continue;
        }
        candidate_buffer[segment][segment_len[segment]] = .{
            .rock = rock,
            .dx = rock.x - station.x,
            .dy = rock.y - station.y,
        };
        segment_len[segment] += 1;
    }
    var segment: usize = 0;
    while (destroyed + segment_len[segment] < 200) {
        destroyed += segment_len[segment];
        segment += 1;
    }
    var candidates = candidate_buffer[segment][0..segment_len[segment]];

    // We will sort the remaining candidates by angle from low to high,
    // without using floating point arithmetic (because... reasons).
    switch (segment) {
        0 => std.sort.sort(AngledRock, candidates, comparison_0),
        1 => std.sort.sort(AngledRock, candidates, comparison_1),
        2 => std.sort.sort(AngledRock, candidates, comparison_2),
        3 => std.sort.sort(AngledRock, candidates, comparison_3),
        else => unreachable,
    }

    const index = 200 - destroyed;
    std.debug.warn("The 200th destroyed asteroid is {}.\n", .{
        candidates[index],
    });
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

fn get_filename(buffer: []u8) ![]const u8 {
    std.debug.warn("filename :: ", .{});
    var stdin = &std.io.getStdIn().inStream().stream;
    var mb_str = try stdin.readUntilDelimiterOrEof(buffer, '\n');
    if (mb_str) |str| {
        if (str.len > 0) {
            return str;
        } else {
            const inputfilename = "10/input.txt";
            return inputfilename[0..];
        }
    } else unreachable;
}

pub fn main() !void {
    var filename_buffer: [100]u8 = undefined;
    var filename = try get_filename(filename_buffer[0..]);
    std.debug.warn("Opening '{}'...\n\n", .{filename});

    var buffer: [MAX_LEN]Rock = undefined;
    var width: i8 = 0;
    var height: i8 = 0;
    const rocks: []Rock = try load(filename, &buffer, &width, &height);

    print_map(width, height, rocks);

    solve(rocks);

    std.debug.warn("\n", .{});
    std.debug.warn("Done.\n", .{});
}
