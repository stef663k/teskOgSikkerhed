const std = @import("std");

pub const WordLists = struct {
    // American English
    pub const american_words =
        @embedFile("american-words.10") ++
        @embedFile("american-words.20") ++
        @embedFile("american-words.35") ++
        @embedFile("american-words.40") ++
        @embedFile("american-words.50") ++
        @embedFile("american-words.55") ++
        @embedFile("american-words.60") ++
        @embedFile("american-words.70") ++
        @embedFile("american-words.80") ++
        @embedFile("american-words.95");

    pub const american_abbreviations =
        @embedFile("american-abbreviations.70") ++
        @embedFile("american-abbreviations.95");

    pub const american_proper_names =
        @embedFile("american-proper-names.50") ++
        @embedFile("american-proper-names.80") ++
        @embedFile("american-proper-names.95");

    pub const american_upper =
        @embedFile("american-upper.50") ++
        @embedFile("american-upper.60") ++
        @embedFile("american-upper.70") ++
        @embedFile("american-upper.80") ++
        @embedFile("american-upper.95");

    // British English
    pub const english_words =
        @embedFile("english-words.10") ++
        @embedFile("english-words.20") ++
        @embedFile("english-words.35") ++
        @embedFile("english-words.40") ++
        @embedFile("english-words.50") ++
        @embedFile("english-words.55") ++
        @embedFile("english-words.60") ++
        @embedFile("english-words.70") ++
        @embedFile("english-words.80") ++
        @embedFile("english-words.95");

    pub const english_abbreviations =
        @embedFile("english-abbreviations.70") ++
        @embedFile("english-abbreviations.95");

    pub const english_proper_names =
        @embedFile("english-proper-names.50");

    // Special categories
    pub const special =
        @embedFile("special-hacker.50") ++
        @embedFile("special-roman-numerals.35");
};

pub fn initWordLists(allocator: std.mem.Allocator) !std.StringArrayHashMap(void) {
    var map = std.StringArrayHashMap(void).init(allocator);

    inline for (@typeInfo(WordLists).Struct.decls) |decl| {
        const list = @field(WordLists, decl.name);
        var iter = std.mem.tokenize(u8, list, "\n");
        while (iter.next()) |word| {
            const trimmed = std.mem.trim(u8, word, " \r");
            if (trimmed.len > 0) {
                try map.put(trimmed, {});
            }
        }
    }

    return map;
}

pub fn isEnglishWord(word: []const u8) bool {
    const normalized = std.ascii.lowerString(word); // Runtime lowercase
    return std.sort.binarySearch([]const u8, normalized, std.mem.splitSequence(u8, english_words, "\x00"), {}, struct {
        pub fn cmp(_: void, a: []const u8, b: []const u8) std.math.Order {
            return std.mem.order(u8, a, b);
        }
    }.cmp) != null;
}

pub const english_words_10 = @embedFile("english-words.10");
pub const english_words_20 = @embedFile("english-words.20");
pub const english_words_35 = @embedFile("english-words.35");
pub const english_words_40 = @embedFile("english-words.40");
pub const english_words_50 = @embedFile("english-words.50");
pub const english_words_55 = @embedFile("english-words.55");
pub const english_words_60 = @embedFile("english-words.60");
pub const english_words_70 = @embedFile("english-words.70");
pub const english_words_80 = @embedFile("english-words.80");
pub const english_words_95 = @embedFile("english-words.95");

pub const american_words_10 = @embedFile("american-words.10");
pub const american_words_20 = @embedFile("american-words.20");
pub const american_words_35 = @embedFile("american-words.35");
pub const american_words_40 = @embedFile("american-words.40");
pub const american_words_50 = @embedFile("american-words.50");
pub const american_words_55 = @embedFile("american-words.55");
pub const american_words_60 = @embedFile("american-words.60");
pub const american_words_70 = @embedFile("american-words.70");
pub const american_words_80 = @embedFile("american-words.80");
pub const american_words_95 = @embedFile("american-words.95");

pub const american_abbreviations_70 = @embedFile("american-abbreviations.70");
pub const american_abbreviations_95 = @embedFile("american-abbreviations.95");
pub const english_abbreviations_70 = @embedFile("english-abbreviations.70");
pub const english_abbreviations_95 = @embedFile("english-abbreviations.95");

pub const american_proper_names_50 = @embedFile("american-proper-names.50");
pub const american_proper_names_80 = @embedFile("american-proper-names.80");
pub const american_proper_names_95 = @embedFile("american-proper-names.95");
pub const english_proper_names_50 = @embedFile("english-proper-names.50");

pub const american_upper_50 = @embedFile("american-upper.50");
pub const american_upper_60 = @embedFile("american-upper.60");
pub const american_upper_70 = @embedFile("american-upper.70");
pub const american_upper_80 = @embedFile("american-upper.80");
pub const american_upper_95 = @embedFile("american-upper.95");

pub const special_hacker_50 = @embedFile("special-hacker.50");
pub const special_roman_numerals_35 = @embedFile("special-roman-numerals.35");
