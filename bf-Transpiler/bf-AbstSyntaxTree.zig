const std = @import("std");
const lxr = @import("bf-Tokeniser.zig");

// file ::= expr* eof
// expr ::= "+" | "-" | ">" | "<" | "," | "." | "[" expr* "]"

const ParseError = error{
    _InvalidProgram_,
};

pub const Ast = struct {
    contents: []const Expr,
    allocator: std.mem.Allocator,

    pub fn free(self: *Ast) void {
        _ = self; // autofix
    }
};

pub const Expr = union(enum) {
    lexeme: lxr.Lexeme,
    brackets: []Expr,
};

pub fn parse(
    lexer: lxr.Lexer,
    allocator: std.mem.Allocator,
) error{_InvalidProgram_}!Ast {
    const list = std.ArrayList(Expr).init(allocator);

    //errdefer //deinit

    while (true) {
        const next = lexer.next();
        switch (next) {
            .@"[" => list.append(.{ .brackets = parse(lxr, allocator) }),
            .@"]" => if () {},
            .eof => {},
            else => list.append(next),
        }
    }
}
