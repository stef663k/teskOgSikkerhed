const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <text> <shift> OR {s} <text> -b\n", .{ args[0], args[0] });
        return;
    }

    const text = args[1];
    const shift_arg = args[2];

    if (std.mem.eql(u8, shift_arg, "-b")) {
        try brute_force(allocator, text);
    } else {
        const shift = try std.fmt.parseInt(i8, shift_arg, 10);
        const encrypted = try caesar(allocator, text, shift);
        defer allocator.free(encrypted);
        std.debug.print("Encrypted: {s}\n", .{encrypted});
    }
}

fn caesar(allocator: std.mem.Allocator, input: []const u8, shift: i8) ![]const u8 {
    const result = try allocator.alloc(u8, input.len);
    std.mem.copyForwards(u8, result, input);

    for (result) |*c| {
        if (c.* >= 'A' and c.* <= 'Z') {
            const base: i32 = 'A';
            const offset = @as(i32, c.*) - base;
            c.* = @intCast(base + @mod(offset + shift, 26));
        } else if (c.* >= 'a' and c.* <= 'z') {
            const base: i32 = 'a';
            const offset = @as(i32, c.*) - base;
            c.* = @intCast(base + @mod(offset + shift, 26));
        }
    }
    return result;
}

fn brute_force(allocator: std.mem.Allocator, encrypted: []const u8) !void {
    std.debug.print("\nBrute-forcing '{s}':\n", .{encrypted});
    for (1..26) |shift| {
        const decrypted = try caesar(allocator, encrypted, -@as(i8, @intCast(shift)));
        defer allocator.free(decrypted);
        std.debug.print("Shift {d: >2}: {s}\n", .{ shift, decrypted });
    }
}

test "caesar cipher basic" {
    const allocator = std.testing.allocator;

    const encrypted1 = try caesar(allocator, "hello", 3);
    defer allocator.free(encrypted1);
    try std.testing.expectEqualStrings("khoor", encrypted1);

    const encrypted2 = try caesar(allocator, "hello", -3);
    defer allocator.free(encrypted2);
    try std.testing.expectEqualStrings("ebiil", encrypted2);
}

test "caesar wrap around" {
    const allocator = std.testing.allocator;

    const encrypted = try caesar(allocator, "zebra", 3);
    defer allocator.free(encrypted);
    try std.testing.expectEqualStrings("cheud", encrypted);
}
