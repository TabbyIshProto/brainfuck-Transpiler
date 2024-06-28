const std = @import("std");
// imports

pub const LexemeTag = enum { //add comments
    num,

    @"+",
    @"-",
    @">",
    @"<",
    openPar,
    closePar,
    @",",
    @".",

    eof,
    invalidette,
};

pub const Lexeme = struct {
    tag: LexemeTag,
    span: [2]usize,
};

pub const Lexer = struct {
    source: []const u8,
    loc: usize = 0,
    peek: ?Lexeme = null,

    pub fn create(source: []const u8) Lexer {
        return Lexer{ .source = source };
    }

    pub fn next(self: *Lexer) void {
        if (self.peek) |token| {
            self.peek = null;
            return token;
        }

        const next_loc = std.mem.indexOfNonePos(u8, self.source, self.loc, &std.ascii.whitespace) orelse
            return Lexeme{ .tag = .eof, .span = .{ self.source.len, self.source.len } };

        const char = self.source[next_loc];
        const tag = switch (char) {
            '0'...'9' => {
                const digits = "1234567890";
                const non_white = std.mem.indexOfNonePos(u8, self.source, next_loc, digits) orelse self.source.len;
                self.loc = non_white;
                const res = Lexeme{ .tag = .num, .span = .{ next_loc, non_white } };
                return res;
            },
            '+', '-', '>', '<' => {
                const caller_char: []const u8 = [1]u8{char};
                const non_white = std.mem.indexOfNonePos(u8, self.source, next_loc, caller_char) orelse self.source.len;
                self.loc = non_white;
                const res = Lexeme{ .tag = switch (char) {
                    '+' => LexemeTag.@"+",
                    '-' => LexemeTag.@"-",
                    '>' => LexemeTag.@">",
                    '<' => LexemeTag.@"<",
                    else => unreachable,
                }, .span = .{ next_loc, non_white } };
                return res;
            },
            '[' => LexemeTag.openPar,
            ']' => LexemeTag.closePar,
            ',' => LexemeTag.@",",
            '.' => LexemeTag.@".",
            else => LexemeTag.invalidette,
        };
        self.loc = next_loc + 1;
        const res = Lexeme{ .tag = tag, .span = .{ next_loc, next_loc + 1 } };
        return res;
    }

    pub fn undo(self: *Lexer, lxm: Lexeme) void {
        std.debug.assert(self.peek == null);
        self.peek = lxm;
    }
};

test "lexer" {
    //nothing here yet :P
}
