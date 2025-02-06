const std = @import("std");
const math = std.math;
const ascii = std.ascii;
const Allocator = std.mem.Allocator;
const testing = std.testing;

const embedded_word_lists = &[_][]const u8{
    @embedFile("wordlist/final/english-words.35"),
    @embedFile("wordlist/final/english-words.50"),
    @embedFile("wordlist/final/english-words.70"),
    @embedFile("wordlist/final/english-words.95"),
    @embedFile("wordlist/final/american-words.20"),
};

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
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const dict_allocator = arena.allocator();

    word_set = std.StringHashMap(void).init(allocator);

    for (embedded_word_lists) |contents| {
        var line_iter = std.mem.split(u8, contents, "\n");

        while (line_iter.next()) |word| {
            if (word.len > 1) { // Skip empty lines
                const cleaned_word = try clean_word(dict_allocator, word);
                try word_set.put(cleaned_word, {});
            }
        }
    }
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
        const test_shift = @as(i8, @intCast(shift));
        const decrypted = try caesar(allocator, normalized, test_shift);
        defer allocator.free(decrypted);

        const scores = .{
            .freq = calculate_frequency_score(decrypted) * 0.2,
            .words = calculate_word_score(decrypted) * 0.7,
            .length = @as(f32, @floatFromInt(count_alpha_chars(decrypted))) / 50.0,
        };

        const total_score = scores.freq + scores.words + scores.length;

        if (total_score > best.score) {
            if (best.score != -1) allocator.free(best.text);

            const restored = try restore_casing(allocator, encrypted, decrypted);
            best = .{ .shift = test_shift, .text = restored, .score = total_score };
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

fn vigenere(allocator: Allocator, text: []const u8, key: []const u8, encrypt: bool) ![]const u8 {
    const processed_key = try processKey(allocator, key);
    defer allocator.free(processed_key);
    if (processed_key.len == 0) return error.EmptyKey;

    var result = try allocator.alloc(u8, text.len);
    var key_idx: usize = 0;

    for (text, 0..) |c, i| {
        if (ascii.isAlphabetic(c)) {
            const key_char = processed_key[key_idx % processed_key.len];
            const shift = if (encrypt)
                @as(i8, @intCast(key_char - @as(u8, 'a')))
            else
                -@as(i8, @intCast(key_char - @as(u8, 'a')));

            const base = if (ascii.isUpper(c))
                @as(u8, 'A')
            else
                @as(u8, 'a');

            const offset = c -% base;
            const new_offset = @mod(@as(i16, offset) + @as(i16, shift), 26);
            result[i] = base + @as(u8, @intCast(new_offset));

            key_idx += 1;
        } else {
            result[i] = c;
        }
    }
    return result;
}

fn processKey(allocator: Allocator, key: []const u8) ![]const u8 {
    var processed = try allocator.alloc(u8, key.len);
    var len: usize = 0;

    for (key) |c| {
        if (ascii.isAlphabetic(c)) {
            processed[len] = ascii.toLower(c);
            len += 1;
        }
    }

    return processed[0..len];
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try load_word_list(allocator);
    defer word_set.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage:\n" ++
            "  File mode: {s} <input> <output> <shift> OR {s} <input> <output> -b\n" ++
            "  String mode: {s} -s <text> <shift> [-b]\n" ++
            "  Vigenère mode: {s} -v <text> <key> [-d] (encrypt/decrypt)\n", .{ args[0], args[0], args[0], args[0] });
        return;
    }

    const stdout = std.io.getStdOut().writer();
    const is_string_mode = std.mem.eql(u8, args[1], "-s");
    const is_vigenere_mode = std.mem.eql(u8, args[1], "-v");

    if (is_string_mode) {
        // String mode handling
        if (args.len < 4) {
            std.debug.print("String mode requires: -s <text> <shift> [-b]\n", .{});
            return;
        }

        const text = args[2];
        const shift_str = args[3];
        const use_brute = args.len >= 5 and std.mem.eql(u8, args[4], "-b");

        if (use_brute) {
            const result = try brute_force(allocator, text);
            try stdout.print("Best candidate (shift {d}, confidence {d:.1}%):\n{s}\n", .{
                result.shift,
                result.confidence,
                result.text,
            });
        } else {
            const shift = try std.fmt.parseInt(i8, shift_str, 10);
            const transformed = try caesar(allocator, text, shift);
            defer allocator.free(transformed);
            try stdout.print("{s}\n", .{transformed});
        }
    } else if (is_vigenere_mode) {
        if (args.len < 4) {
            std.debug.print("Vigenère mode requires: -v <text> <key> [-d]\n", .{});
            return;
        }

        const text = args[2];
        const key = args[3];
        const decrypt = args.len >= 5 and std.mem.eql(u8, args[4], "-d");

        const transformed = try vigenere(allocator, text, key, !decrypt);
        defer allocator.free(transformed);
        try stdout.print("{s}\n", .{transformed});
    } else {
        // Original file mode handling
        if (args.len < 4) {
            std.debug.print("File mode requires: <input> <output> <shift> OR <input> <output> -b\n", .{});
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
            try output_file.writer().print("Best candidate (shift {d}, confidence {d:.1}%):\n{s}\n", .{
                result.shift,
                result.confidence,
                result.text,
            });
        } else {
            const shift = try std.fmt.parseInt(i8, args[3], 10);
            const encrypted = try caesar(allocator, text, shift);
            defer allocator.free(encrypted);
            try output_file.writer().writeAll(encrypted);
        }
    }
}

fn caesar(allocator: Allocator, text: []const u8, shift: i8) ![]const u8 {
    var result = try allocator.alloc(u8, text.len);
    const positive_shift = @as(u8, @intCast(@mod(shift, 26)));

    for (text, 0..) |char, i| {
        if (std.ascii.isASCII(char) and std.ascii.isAlphabetic(char)) {
            const base: u8 = if (std.ascii.isUpper(char)) 'A' else 'a';
            const offset = char -% base;
            const new_offset = (offset + positive_shift) % 26;
            result[i] = base + new_offset;
        } else {
            result[i] = char;
        }
    }

    return result;
}

fn count_alpha_chars(text: []const u8) usize {
    var count: usize = 0;
    for (text) |c| {
        if (std.ascii.isAlphabetic(c)) count += 1;
    }
    return count;
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

test "Known Shift Validation" {
    const allocator = testing.allocator;

    // Initialize word list for dictionary checks
    try load_word_list(allocator);
    defer word_set.deinit();

    const original = "Hello World!";
    const encrypted = try caesar(allocator, original, 5);
    defer allocator.free(encrypted);

    const decrypted = try brute_force(allocator, encrypted);
    defer allocator.free(decrypted.text);

    try testing.expectEqual(@as(i8, 5), decrypted.shift);
    try testing.expectEqualStrings(original, decrypted.text);
}

test "Vigenère basic encryption" {
    const allocator = testing.allocator;
    const encrypted = try vigenere(allocator, "ATTACKATDAWN", "LEMON", true);
    defer allocator.free(encrypted);
    try testing.expectEqualStrings("LXFOPVEFRNHR", encrypted);
}

test "Vigenère basic decryption" {
    const allocator = testing.allocator;
    const decrypted = try vigenere(allocator, "LXFOPVEFRNHR", "LEMON", false);
    defer allocator.free(decrypted);
    try testing.expectEqualStrings("ATTACKATDAWN", decrypted);
}

test "Vigenère with non-letters" {
    const allocator = testing.allocator;
    const encrypted = try vigenere(allocator, "Hello, World!", "KEY", true);
    defer allocator.free(encrypted);
    try testing.expectEqualStrings("Rijvs, Uyvjn!", encrypted);
}
