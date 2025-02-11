const std = @import("std");
const math = std.math;
const ascii = std.ascii;
const Allocator = std.mem.Allocator;
const testing = std.testing;
const wordlists = @import("wordlists");

const embedded_word_lists = &[_]type{@TypeOf(wordlists.word_set)};

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

const bloom = struct {
    const size = 1 << 24;
    var bits: [size]bool = undefined;

    pub fn init() void {
        @setCold(true);
        for (&bits) |*b| b.* = false;
        var word_iter = wordlists.word_set.keyIterator();
        while (word_iter.next()) |word_ptr| {
            const word = word_ptr.*;
            for (word) |char| {
                const bytes = [_]u8{char};
                const h = std.hash.Wyhash.hash(0, &bytes);
                bits[h % size] = true;
                bits[(h >> 8) % size] = true;
                bits[(h >> 16) % size] = true;
            }
        }
    }

    pub fn contains(word: []const u8) bool {
        const h = std.hash.Wyhash.hash(0, word.bytes);
        return bits[h % size] and
            bits[(h >> 8) % size] and
            bits[(h >> 16) % size];
    }
};

pub fn isEnglishWord(word: []const u8) bool {
    return bloom.contains(word);
}

fn load_word_list(allocator: Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const dict_allocator = arena.allocator();
    _ = dict_allocator;

    var word_iter = wordlists.word_set.keyIterator();
    while (word_iter.next()) |word_ptr| {
        const word = word_ptr.*;
        for (word) |char| {
            _ = char;
            // Use 'char' which is of type u8
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

fn countMatchingWords(text: []const u8) u32 {
    var count: u32 = 0;
    var words = std.mem.tokenizeAny(u8, text, " \t\n\r");

    while (words.next()) |word| {
        var lower_word: [256]u8 = undefined;
        const lower_slice = std.ascii.lowerString(&lower_word, word);

        if (wordlists.contains(lower_slice)) {
            count += 1;
        }
    }
    return count;
}

fn calculate_word_score(allocator: Allocator, text: []const u8) !f32 {
    var valid: u32 = 0;
    var total: u32 = 0;

    var words = std.mem.tokenizeAny(u8, text, " \t\n\r");
    while (words.next()) |word| {
        const trimmed = std.mem.trim(u8, word, " \t\n\r.,!?;:\"'()");
        if (trimmed.len == 0) continue;

        var lower_word = try allocator.alloc(u8, trimmed.len);
        defer allocator.free(lower_word);
        for (trimmed, 0..) |c, i| {
            lower_word[i] = std.ascii.toLower(c);
        }

        if (wordlists.isEnglishWord(lower_word)) valid += 1;
        total += 1;
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

const BruteForceResult = struct {
    shift: i32,
    text: []const u8,
};

fn brute_force(allocator: Allocator, text: []const u8) !BruteForceResult {
    var best_shift: i32 = 0;
    var best_score: u32 = 0;

    // Check all possible shifts (0-25)
    for (0..26) |shift| {
        const decrypted = try caesar(allocator, text, @as(i32, @intCast(shift)));
        defer allocator.free(decrypted);

        const score = countMatchingWords(decrypted);
        if (score > best_score) {
            best_score = score;
            best_shift = @as(i32, @intCast(shift));
        }
    }

    // Recreate the best decryption
    const best_text = try caesar(allocator, text, -best_shift);
    return BruteForceResult{
        .shift = best_shift,
        .text = best_text,
    };
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

fn restore_casing(allocator: Allocator, original: []const u8, modified: []const u8) ![]u8 {
    const restored = try allocator.alloc(u8, original.len);

    for (original, modified, 0..) |orig_char, mod_char, i| {
        if (i >= modified.len) break;

        restored[i] = if (std.ascii.isUpper(orig_char))
            std.ascii.toUpper(mod_char)
        else
            std.ascii.toLower(mod_char);
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
                key_char - 'a'
            else
                26 - (key_char - 'a');

            const base: u8 = if (ascii.isUpper(c)) @as(u8, 'A') else @as(u8, 'a');

            const shifted = (c -% base +% shift) % 26;
            result[i] = base + shifted;

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

fn decrypt(allocator: Allocator, text: []const u8, shift: u8) ![]u8 {
    var decrypted = try allocator.alloc(u8, text.len);
    for (text, 0..) |char, i| {
        if (std.ascii.isAlphabetic(char)) {
            const base: u8 = if (std.ascii.isUpper(char))
                @as(u8, 'A') // Explicit cast
            else
                @as(u8, 'a'); // Explicit cast

            const offset = (char -% base);
            const shifted = (offset +% (26 -% shift)) % 26;
            decrypted[i] = base + shifted;
        } else {
            decrypted[i] = char;
        }
    }
    return decrypted;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try wordlists.init(allocator);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator_gpa = gpa.allocator();

    bloom.init();
    try load_word_list(allocator_gpa);

    const args = try std.process.argsAlloc(allocator_gpa);
    defer std.process.argsFree(allocator_gpa, args);

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
            const result = try brute_force(allocator_gpa, text);
            try stdout.print("Best candidate (shift {d}, confidence {d:.1}%):\n{s}\n", .{
                result.shift,
                result.score * 100,
                result.text,
            });
        } else {
            const shift = try std.fmt.parseInt(i8, shift_str, 10);
            const transformed = try caesar(allocator_gpa, text, shift);
            defer allocator_gpa.free(transformed);
            try stdout.print("{s}\n", .{transformed});
        }
    } else if (is_vigenere_mode) {
        if (args.len < 4) {
            std.debug.print("Vigenère mode requires: -v <text> <key> [-d]\n", .{});
            return;
        }

        const text = args[2];
        const key = args[3];
        const decrypt_flag = args.len >= 5 and std.mem.eql(u8, args[4], "-d");

        const transformed = try vigenere(allocator_gpa, text, key, !decrypt_flag);
        defer allocator_gpa.free(transformed);
        try stdout.print("{s}\n", .{transformed});
    } else {
        // Original file mode handling
        if (args.len < 4) {
            std.debug.print("File mode requires: <input> <output> <shift> OR <input> <output> -b\n", .{});
            return;
        }

        const input_file = try std.fs.cwd().openFile(args[1], .{});
        defer input_file.close();
        const text = try input_file.readToEndAlloc(allocator_gpa, std.math.maxInt(usize));
        defer allocator_gpa.free(text);

        const output_file = try std.fs.cwd().createFile(args[2], .{});
        defer output_file.close();

        const decrypt_flag = args.len >= 5 and std.mem.eql(u8, args[4], "-d");
        const shift = try std.fmt.parseInt(i8, args[3], 10);

        if (decrypt_flag) {
            const decrypted = try decrypt(allocator_gpa, text, @as(u8, @intCast(-shift)));
            defer allocator_gpa.free(decrypted);
            try output_file.writer().writeAll(decrypted);
        } else {
            const encrypted = try caesar(allocator_gpa, text, shift);
            defer allocator_gpa.free(encrypted);
            try output_file.writer().writeAll(encrypted);
        }
    }
}

fn caesar(allocator: Allocator, text: []const u8, shift: i32) ![]const u8 {
    var result = try allocator.alloc(u8, text.len);
    const normalized_shift = @mod(shift, 26);

    for (text, 0..) |c, i| {
        if (std.ascii.isAlphabetic(c)) {
            const base = if (std.ascii.isUpper(c))
                @as(u8, 'A')
            else
                @as(u8, 'a');

            const raw_offset = @as(i32, c) - base + normalized_shift;
            const wrapped_offset = @mod(raw_offset, 26);
            const offset = @as(u8, @intCast(wrapped_offset));

            result[i] = base + offset;
        } else {
            result[i] = c;
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
            else => if (std.ascii.isAlphabetic(c)) c else 0,
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
    const allocator = std.testing.allocator;
    const encrypted = try caesar(allocator, "Hello world", 13);
    defer allocator.free(encrypted);

    const result = try brute_force(allocator, encrypted);
    defer allocator.free(result.text);

    try std.testing.expectEqualStrings("Hello world", result.text);
    try std.testing.expectEqual(@as(i32, 13), result.shift);
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
