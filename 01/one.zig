//snap/bin/zig build-exe 01/one.zig --output-dir 01/ --name .one && time 01/one "$@"; exit

const std = @import("std");
const fmt = @import("std").fmt;

pub fn main() !void {
    const stdout_file = try std.io.getStdOut();
    try stdout_file.write("Hello, world!\n");
}
