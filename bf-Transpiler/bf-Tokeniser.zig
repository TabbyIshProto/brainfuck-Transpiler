const std = @import("std");
// imports

pub const Lexeme = enum { @"+", @"-", @">", @"<", @"[", @"]", @",", @".", eof };

pub const Lexer = struct {
    source: []const u8,

    pub fn create(source: []const u8) Lexer {
        return Lexer{ .source = source };
    }

    pub fn next(self: *Lexer) Lexeme {
        return while (self.source.len != 0) {
            const char = self.source[0];
            self.source = self.source[1..];
            switch (char) {
                '+' => break .@"+",
                '-' => break .@"-",
                '>' => break .@">",
                '<' => break .@"<",
                '[' => break .@"[",
                ']' => break .@"]",
                ',' => break .@",",
                '.' => break .@".",
                else => continue,
            }
        } else .eof;
    }
};
