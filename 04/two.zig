const std = @import("std");
const fmt = @import("std").fmt;
const File = std.fs.File;

pub fn main() void {
    var n_matches: u32 = 0;

    // The numbers have to be non-decreasing, so the first match higher or equal
    // to 240298 is 244444.
    var a: u8 = 2;
    var b: u8 = 4;
    var c: u8 = 4;
    var d: u8 = 4;
    var e: u8 = 4;
    var f: u8 = 4;

    all: while (a < 8) {
        while (b < 10) {
            while (c < 10) {
                while (d < 10) {
                    while (e < 10) {
                        while (f < 10) {
                            // The numbers have to be non-decreasing, so there
                            // are no matches between 780000 and 784956.
                            // In fact if we get here, we'll be at 788888.
                            if (a == 7 and b == 8) {
                                break :all;
                            } else if (a == b and b != c) {
                                //std.debug.warn("Found {}{}{}{}{}{}\n", a, b, c, d, e, f);
                                n_matches += 1;
                            } else if (a != b and b == c and c != d) {
                                //std.debug.warn("Found {}{}{}{}{}{}\n", a, b, c, d, e, f);
                                n_matches += 1;
                            } else if (b != c and c == d and d != e) {
                                //std.debug.warn("Found {}{}{}{}{}{}\n", a, b, c, d, e, f);
                                n_matches += 1;
                            } else if (c != d and d == e and e != f) {
                                //std.debug.warn("Found {}{}{}{}{}{}\n", a, b, c, d, e, f);
                                n_matches += 1;
                            } else if (d != e and e == f) {
                                //std.debug.warn("Found {}{}{}{}{}{}\n", a, b, c, d, e, f);
                                n_matches += 1;
                            }
                            f += 1;
                        }
                        e += 1;
                        f = e;
                    }
                    d += 1;
                    e = d;
                    f = d;
                }
                c += 1;
                d = c;
                e = c;
                f = c;
            }
            b += 1;
            c = b;
            d = b;
            e = b;
            f = b;
        }
        a += 1;
        b = a;
        c = a;
        d = a;
        e = a;
        f = a;
    }

    std.debug.warn("\n");
    std.debug.warn("Number of matches found: {}\n", n_matches);
}
