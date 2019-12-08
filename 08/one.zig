const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

const MAX_LAYERS = 100;
const LAYER_WIDTH = 25;
const LAYER_HEIGHT = 6;
const LAYER_SIZE = LAYER_WIDTH * LAYER_HEIGHT;
const Layer = [LAYER_SIZE]u2;

fn load(fname: []const u8, layers: *[MAX_LAYERS]Layer) ![]Layer {
    const input = try File.openRead(fname);
    defer input.close();

    const strm = &input.inStream().stream;
    var buffer: [LAYER_SIZE]u8 = undefined;
    var n_layers: u16 = 0;
    while (n_layers < MAX_LAYERS + 1) {
        const len = try strm.readFull(buffer[0..]);
        const trimmed = std.mem.trim(u8, buffer[0..len], "\r\n ");
        if (trimmed.len == 0) {
            return layers[0..n_layers];
        }
        std.debug.assert(trimmed.len == buffer.len);
        for (trimmed) |byte, i| {
            std.debug.assert(byte >= '0' and byte <= '2');
            layers[n_layers][i] = @intCast(u2, byte - '0');
        }
        n_layers += 1;
    }
    unreachable;
}

fn solve(layers: []Layer) usize {
    var best_zerocount: usize = 0;
    var best_is_tied: bool = false;
    var best_score: usize = undefined;

    for (layers) |layer| {
        var count = [_]usize{0} ** 3;

        for (layer) |digit| {
            count[digit] += 1;
        }

        if (count[0] > best_zerocount) {
            best_zerocount = count[0];
            best_is_tied = false;
            best_score = count[1] * count[2];
        } else if (count[0] == best_zerocount) {
            best_is_tied = true;
        }
    }

    std.debug.assert(!best_is_tied);
    return best_score;
}

pub fn main() !void {
    const filename = "08/input.txt";

    var layers_buffer: [MAX_LAYERS][LAYER_SIZE]u2 = undefined;
    const layers: [][LAYER_SIZE]u2 = try load(filename, &layers_buffer);

    std.debug.warn("Parsed {} layers.\n", layers.len);

    const solution = solve(layers);
    std.debug.warn("Solution: {}\n", solution);

    std.debug.warn("\n");
    std.debug.warn("Done.\n");
}
