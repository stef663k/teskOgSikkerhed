const std = @import("std");
const math = std.math;
const ascii = std.ascii;
const Allocator = std.mem.Allocator;

var word_set: std.StringHashMap(void) = undefined;

const EnglishFrequencies = struct {
    const letter_probs = [26]f32{
        0.08167, 0.01492, 0.02782, 0.04258, 0.12702, // a-e
        0.02228, 0.02015, 0.06094, 0.06966, 0.00153, // f-j
        0.00772, 0.04025, 0.02406, 0.06749, 0.07507, // k-o
        0.01929, 0.00095, 0.05987, 0.06327, 0.09056, // p-t
        0.02758, 0.00978, 0.02360, 0.00150, 0.01974, // u-y
        0.00074, // z
    };

    fn get(ch: u8) f32 {
        const lower = ascii.toLower(ch);
        return if (lower >= 'a' and lower <= 'z')
            letter_probs[lower - 'a']
        else
            0.0;
    }
};

fn load_word_list(allocator: Allocator) !void {
    const word_lists = &[_][]const u8{
        "wordlist/final/english-words.35",
        "wordlist/final/english-words.50",
        "wordlist/final/english-words.70",
        "wordlist/final/english-words.95",
        "wordlist/final/american-words.20",
    };

    word_set = std.StringHashMap(void).init(allocator);
    try word_set.ensureTotalCapacity(200_000);

    var total_entries: usize = 0;
    var unique_words: usize = 0;

    for (word_lists) |path| {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();
        var buf: [1024]u8 = undefined;

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            total_entries += 1;
            const raw_word = std.mem.trim(u8, line, " \r\n");

            if (raw_word.len == 0) continue;

            var lower_buf: [1024]u8 = undefined;
            const word = std.ascii.lowerString(lower_buf[0..raw_word.len], raw_word);

            const owned_word = try allocator.dupe(u8, word);

            if (!word_set.contains(owned_word)) {
                try word_set.put(owned_word, {});
                unique_words += 1;
            } else {
                allocator.free(owned_word);
            }
        }
    }

    std.debug.print("Successfully loaded {d} unique words from {d} total entries\n", .{ unique_words, total_entries });
}

fn clean_word(allocator: Allocator, word: []const u8) ![]const u8 {
    var cleaned = try allocator.alloc(u8, word.len);
    var len: usize = 0;

    for (word) |ch| {
        if (ascii.isAlphabetic(ch)) {
            cleaned[len] = ascii.toLower(ch);
            len += 1;
        }
    }

    return cleaned[0..len];
}

fn calculate_word_score(text: []const u8) f32 {
    var words = std.mem.tokenizeAny(u8, text, " \t\n\r,.;:'\"()!?");
    var valid: usize = 0;
    var total: usize = 0;

    while (words.next()) |word| {
        total += 1;
        if (word_set.contains(word)) valid += 1;
    }

    return if (total > 0)
        @as(f32, @floatFromInt(valid)) / @as(f32, @floatFromInt(total))
    else
        0;
}

fn calculate_frequency_score(text: []const u8) f32 {
    var counts: [26]u32 = [_]u32{0} ** 26;
    var total: u32 = 0;

    for (text) |ch| {
        const lower = ascii.toLower(ch);
        if (lower >= 'a' and lower <= 'z') {
            counts[lower - 'a'] += 1;
            total += 1;
        }
    }

    var score: f32 = 0.0;
    if (total > 0) {
        for (counts, 0..) |count, i| {
            const observed = @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(total));
            const expected = EnglishFrequencies.letter_probs[i];
            const diff = observed - expected;
            score += (diff * diff) / expected;
        }
    }
    return -score;
}

fn brute_force(allocator: Allocator, encrypted: []const u8) !struct { shift: i8, text: []u8, confidence: f32 } {
    const normalized = try normalize_text(allocator, encrypted);
    defer allocator.free(normalized);

    var best: struct { shift: i8, text: []u8, score: f32 } = .{ .shift = 0, .text = undefined, .score = -1 };

    for (0..26) |shift| {
        const decrypted = try caesar(allocator, normalized, @as(i8, @intCast(shift)));
        defer allocator.free(decrypted);

        const scores = .{
            .freq = calculate_frequency_score(decrypted) * 0.4,
            .words = calculate_word_score(decrypted) * 0.5,
            .length = @as(f32, @floatFromInt(decrypted.len)) / 10000.0,
        };

        const total_score = scores.freq + scores.words + scores.length;

        if (total_score > best.score) {
            best = .{ .shift = @as(i8, @intCast(shift)), .text = try restore_casing(allocator, encrypted, decrypted), .score = total_score };
        }
    }

    return .{ .shift = best.shift, .text = best.text, .confidence = @min(best.score * 100, 100) };
}

fn normalize_text(allocator: Allocator, text: []const u8) ![]const u8 {
    var normalized = try allocator.alloc(u8, text.len);
    for (text, 0..) |c, i| {
        normalized[i] = if (std.ascii.isAlphabetic(c))
            std.ascii.toLower(c)
        else
            c;
    }
    return normalized;
}

fn restore_casing(allocator: Allocator, original: []const u8, decrypted: []const u8) ![]u8 {
    var restored = try allocator.alloc(u8, decrypted.len);
    for (decrypted, 0..) |c, i| {
        restored[i] = if (i < original.len and std.ascii.isUpper(original[i]))
            std.ascii.toUpper(c)
        else
            c;
    }
    return restored;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try load_word_list(allocator);
    defer word_set.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: {s} <input> <output> <shift> OR {s} <input> <output> -b\n", .{ args[0], args[0] });
        return;
    }

    const input_file = try std.fs.cwd().openFile(args[1], .{});
    defer input_file.close();
    const text = try input_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(text);

    const output_file = try std.fs.cwd().createFile(args[2], .{});
    defer output_file.close();

    if (std.mem.eql(u8, args[3], "-b")) {
        const result = try brute_force(allocator, text);
        try output_file.writer().print("Best candidate (shift {d}, confidence {d:.1}%):\n{s}\n", .{ result.shift, result.confidence, result.text });
    } else {
        const shift = try std.fmt.parseInt(i8, args[3], 10);
        const encrypted = try caesar(allocator, text, shift);
        defer allocator.free(encrypted);
        try output_file.writer().writeAll(encrypted);
    }
}

fn caesar(allocator: Allocator, text: []const u8, shift: i8) ![]const u8 {
    var result = try allocator.alloc(u8, text.len);
    const normalized_shift = @mod(shift, 26);

    for (text, 0..) |char, i| {
        if (ascii.isAlphabetic(char)) {
            const base: u8 = if (ascii.isUpper(char)) 'A' else 'a';
            const offset = @as(i16, char) - base;
            const new_offset = @mod(offset + normalized_shift, 26);
            result[i] = @intCast(base + new_offset);
        } else {
            result[i] = char;
        }
    }

    return result;
}
fn clean_lyrics(allocator: Allocator, text: []const u8) ![]const u8 {
    var cleaned = try allocator.alloc(u8, text.len);
    var len: usize = 0;

    for (text) |c| {
        const safe_char = switch (c) {
            0x2018, 0x2019 => '\'',
            0x201C, 0x201D => '"',
            0x2014 => '-',
            else => if (std.ascii.isASCII(c)) c else 0,
        };

        if (safe_char != 0) {
            cleaned[len] = safe_char;
            len += 1;
        }
    }

    return cleaned[0..len];
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
