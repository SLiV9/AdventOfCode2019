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

fn display(layers: []Layer) void {
    var output: Layer = [_]u2{3} ** LAYER_SIZE;

    for (layers) |layer| {
        for (layer) |bit, i| {
            if (bit < 2 and output[i] > 2) {
                output[i] = bit;
            }
        }
    }

    for (output) |bit, i| {
        switch (bit) {
            0 => std.debug.warn(" "),
            1 => std.debug.warn("X"),
            else => unreachable,
        }
        if ((i + 1) % LAYER_WIDTH == 0) {
            std.debug.warn("\n");
        }
    }
}

pub fn main() !void {
    const filename = "08/input.txt";

    var layers_buffer: [MAX_LAYERS][LAYER_SIZE]u2 = undefined;
    const layers: [][LAYER_SIZE]u2 = try load(filename, &layers_buffer);

    display(layers);

    std.debug.warn("\n");
    std.debug.warn("Done.\n");
}
