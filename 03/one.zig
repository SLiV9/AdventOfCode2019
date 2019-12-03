const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const Move = struct {
    way: u8,
    dis: u32,
};

fn parse_snake(line: []u8, snake: *[1000]Move) ![]Move {
    var len: usize = 0;

    var it = std.mem.tokenize(line, ",");
    while (it.next()) |str| {
        std.debug.assert(len < snake.len);
        snake[len] = Move{
            .way = str[0],
            .dis = try fmt.parseInt(u32, str[1..], 10),
        };
        len += 1;
    }

    return snake[0..len];
}

fn parse_snakes(filename: []const u8, buffer: *[10][1000]Move, snakes: *[10][]Move) ![][]Move {
    const input = try File.openRead("03/sample1.txt");
    defer input.close();

    var len: usize = 0;

    var istrm = &input.inStream().stream;
    var linebuffer: [1000]u8 = undefined;
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

pub fn main() !void {
    var xxx: [10][1000]Move = undefined;
    var yyy: [10][]Move = undefined;
    const snakes = try parse_snakes("03/sample1.txt", &xxx, &yyy);

    for (snakes) |snake| {
        for (snake) |move| {
            std.debug.warn("{c}{} ", move.way, move.dis);
        }
        std.debug.warn(" ({})\n", snake.len);
    }

    std.debug.warn("\nDone.\n");
}
