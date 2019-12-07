const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const MAX_MAP_SIZE = 1000;
const MAX_NAME_LEN = 3;

fn load_orbit_map(filename: []const u8, map: *[MAX_MAP_SIZE]u16) ![]u16 {
    const input = try File.openRead(filename);
    defer input.close();

    std.debug.assert(MAX_MAP_SIZE < 0xFFFF);
    var names: [MAX_MAP_SIZE][MAX_NAME_LEN:0]u8 = undefined;

    const strm = &input.inStream().stream;
    var buffer: [2 * MAX_NAME_LEN + 1]u8 = undefined;
    var len: u16 = 0;
    while (len < MAX_MAP_SIZE) {
        var mb_line = try strm.readUntilDelimiterOrEof(buffer[0..], '\n');
        if (mb_line) |line| {
            //std.debug.warn("Parsing '{}'...\n", line);
            var planetname = [_]u8{0} ** MAX_NAME_LEN;
            var moonname = [_]u8{0} ** MAX_NAME_LEN;

            var it = std.mem.tokenize(line, ")");
            if (it.next()) |str| {
                if (str.len <= MAX_NAME_LEN) {
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
                if (str.len <= MAX_NAME_LEN) {
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

            const planet = find_appropriate_index(names[0..len], planetname[0..]);
            if (planet == len) {
                std.mem.copy(u8, names[len][0..], planetname[0..]);
                map[len] = len;
                len += 1;
            }
            const moon = find_appropriate_index(names[0..len], moonname[0..]);
            //std.debug.warn("{} orbits {}\n", moon, planet);
            if (moon == len) {
                std.mem.copy(u8, names[len][0..], moonname[0..]);
                map[len] = planet;
                len += 1;
            } else {
                std.debug.assert(map[moon] == moon);
                map[moon] = planet;
            }
        } else {
            return map[0..len];
        }
    }
    unreachable;
}

fn find_appropriate_index(names: [][MAX_NAME_LEN:0]u8, objectname: []u8) u16 {
    for (names) |name, i| {
        if (std.mem.eql(u8, name[0..], objectname)) {
            return @intCast(u16, i);
        }
    }
    std.debug.assert(names.len < MAX_MAP_SIZE);
    return @intCast(u16, names.len);
}

pub fn main() !void {
    var n_orbits: usize = 0;

    var map_buffer: [MAX_MAP_SIZE]u16 = undefined;
    const map: []u16 = try load_orbit_map("06/input.txt", &map_buffer);

    for (map) |xx, i| {
        var x: u16 = xx;
        std.debug.assert(i < map.len);
        var y: u16 = @intCast(u16, i);
        //std.debug.warn("{}", y);
        while (x != y) {
            n_orbits += 1;
            //std.debug.warn(" orbits {}", x);
            y = x;
            x = map[x];
        }
        //std.debug.warn("\n");
    }

    std.debug.warn("\n");
    std.debug.warn("Number of direct and indirect orbits: {}\n", n_orbits);
}
