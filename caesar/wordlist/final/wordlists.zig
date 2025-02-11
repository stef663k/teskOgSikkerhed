const std = @import("std");

pub var word_set: std.StringHashMap(void) = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    const raw_data = @embedFile("combined.bin");
    word_set = std.StringHashMap(void).init(allocator);

    var iter = std.mem.split(u8, raw_data, "\n");
    while (iter.next()) |line| {
        if (line.len > 0) {
            try word_set.put(line, {});
        }
    }
}

pub fn contains(word: []const u8) bool {
    return word_set.contains(word);
}

pub fn isEnglishWord(word: []const u8) bool {
    var buffer: [256]u8 = undefined;
    const lower_word = std.ascii.lowerString(&buffer, word);
    return word_set.contains(lower_word);
}
