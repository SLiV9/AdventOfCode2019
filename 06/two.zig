const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const MAX_LEN = 1000;
const NAMESIZE = 3;

fn load(fname: []const u8, map: *[MAX_LEN]u16, you: *u16, santa: *u16) ![]u16 {
    const input = try File.openRead(fname);
    defer input.close();

    std.debug.assert(MAX_LEN < 0xFFFF);
    var names: [MAX_LEN][NAMESIZE:0]u8 = undefined;

    const strm = &input.inStream().stream;
    var buffer: [2 * NAMESIZE + 1]u8 = undefined;
    var len: u16 = 0;
    while (len < MAX_LEN) {
        var mb_line = try strm.readUntilDelimiterOrEof(buffer[0..], '\n');
        if (mb_line) |line| {
            var planetname = [_]u8{0} ** NAMESIZE;
            var moonname = [_]u8{0} ** NAMESIZE;

            var it = std.mem.tokenize(line, ")");
            if (it.next()) |str| {
                if (str.len <= NAMESIZE) {
                    std.mem.copy(u8, planetname[0..], str);
                } else {
                    std.debug.warn("Invalid line '{}'\n", line);
                    unreachable;
                }
            } else {
                std.debug.warn("Invalid line '{}'\n", line);
                unreachable;
            }
            if (it.next()) |str| {
                if (str.len <= NAMESIZE) {
                    std.mem.copy(u8, moonname[0..], str);
                } else {
                    std.debug.warn("Invalid line '{}'\n", line);
                    unreachable;
                }
            } else {
                std.debug.warn("Invalid line '{}'\n", line);
                unreachable;
            }
            if (it.next()) |_| {
                std.debug.warn("Invalid line '{}'\n", line);
                unreachable;
            }

            const planet = find(names[0..len], planetname[0..]);
            if (planet == len) {
                std.mem.copy(u8, names[len][0..], planetname[0..]);
                map[len] = len;
                len += 1;
            }
            const moon = find(names[0..len], moonname[0..]);
            if (moon == len) {
                std.mem.copy(u8, names[len][0..], moonname[0..]);
                map[len] = planet;
                len += 1;
            } else {
                std.debug.assert(map[moon] == moon);
                map[moon] = planet;
            }

            if (std.mem.eql(u8, "YOU", moonname[0..])) {
                you.* = moon;
            } else if (std.mem.eql(u8, "SAN", moonname[0..])) {
                santa.* = moon;
            }
        } else {
            return map[0..len];
        }
    }
    unreachable;
}

fn find(names: [][NAMESIZE:0]u8, objectname: []u8) u16 {
    for (names) |name, i| {
        if (std.mem.eql(u8, name[0..], objectname)) {
            return @intCast(u16, i);
        }
    }
    std.debug.assert(names.len < MAX_LEN);
    return @intCast(u16, names.len);
}

pub fn main() !void {
    var you: u16 = 0xFFFF;
    var santa: u16 = 0xFFFF;

    const filename = "06/input.txt";

    var map_buffer: [MAX_LEN]u16 = undefined;
    const map: []u16 = try load(filename, &map_buffer, &you, &santa);

    std.debug.assert(you < map.len);
    std.debug.assert(santa < map.len);

    std.debug.warn("Looking for route from {} to {}.\n", you, santa);
    var n_transfers: usize = 0;

    var visited_buffer = [_]bool{false} ** MAX_LEN;
    var visited = visited_buffer[0..map.len];
    {
        var y = you;
        var x = map[y];
        visited[y] = true;
        while (x != y) {
            visited[x] = true;
            y = x;
            x = map[y];
        }
    }

    const hinge: u16 = find_hinge: {
        var y = santa;
        var x = map[y];
        while (x != y) {
            if (visited[x]) {
                break :find_hinge x;
            }
            n_transfers += 1;
            y = x;
            x = map[y];
        }
        unreachable;
    };

    std.debug.warn("The path hinges at {}.\n", hinge);

    {
        var y = you;
        var x = map[y];
        while (x != hinge) {
            n_transfers += 1;
            y = x;
            x = map[y];
        }
    }

    std.debug.warn("\n");
    std.debug.warn("Number of direct and indirect orbits: {}\n", n_transfers);
}
