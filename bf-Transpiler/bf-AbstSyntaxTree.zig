const std = @import("std");
const tokeniser = @import("bf-Tokeniser.zig");

const lxr = tokeniser.Lexer;
const lxm = tokeniser.Lexeme;

pub fn parse(
    source: []const u8,
    allocator: std.mem.Allocator,
) error{ OutOfMemory, ParseError }!File {
    var lexer = lxr.create(source);
    return try File.parse(&lexer, allocator);
}

// file ::= expr* eof
// macro ::= expr* "=" "identifier"*
// expr ::= "+" | "-" | ">" | "<" | "," "identifier"* | "." "identifier"* | "[" expr* "]" | *macro | "^" | "v"

pub const File = struct {
    expressions: []const Expr,
    eof: [2]usize,

    fn parse(
        lexer: *lxr,
        allocator: std.mem.Allocator,
    ) error{ OutOfMemory, ParseError }!File {
        var expre_list = std.ArrayList(Expr).init(allocator);
        errdefer {
            for (expre_list.items) |expression| {
                expression.deinit(allocator);
            }
            expre_list.deinit();
        }

        while (true) {
            const token = lexer.next();
            switch (token.tag) {
                .eof => return File{
                    .expressions = try expre_list.toOwnedSlice(),
                    .eof = token.span,
                },
                else => {
                    lexer.undo(token);
                    const expression = try Expr.parse(lexer, allocator);
                    try expre_list.append(expression);
                },
            }
        }
    }

    fn deinit(self: File, allocator: std.mem.Allocator) void {
        for (self.expressions) |expression| {
            expression.deinit(allocator);
        }
        allocator.free(self.expressions);
    }
};

// expr ::= "+" | "-" | ">" | "<" | "," | "." | "[" expr* "]"

pub const Expr = union(enum) {
    plus: [2]usize,
    minus: [2]usize,
    r_arrow: [2]usize,
    l_arrow: [2]usize,
    in: [2]usize,
    out: [2]usize,
    par: Parenthesis,

    const Parenthesis = struct {
        open_paren: [2]usize,
        abstraction: []const Expr,
        close_paren: [2]usize,
    };

    fn parse(
        lexer: *lxr,
        allocator: std.mem.Allocator,
    ) error{ OutOfMemory, ParseError }!Expr {
        const token = lexer.next();
        switch (token.tag) {
            .openPar => {
                var abstract_list = std.ArrayList(Expr).init(allocator);
                errdefer {
                    for (abstract_list.items) |ex| {
                        ex.deinit(allocator);
                    }
                    abstract_list.deinit();
                }
                const open_span = token.span;
                while (true) {
                    const tok = lexer.next();
                    switch (tok.tag) {
                        .closePar => {
                            return Expr{ .par = .{
                                .open_paren = open_span,
                                .abstraction = try abstract_list.toOwnedSlice(),
                                .close_paren = tok.span,
                            } };
                        },
                        else => {
                            lexer.undo(tok);
                            const abstraction = try Expr.parse(lexer, allocator);
                            try abstract_list.append(abstraction);
                        },
                    }
                }
            },
            .@"+" => return Expr{ .plus = token.span },
            .@"-" => return Expr{ .minus = token.span },
            .@">" => return Expr{ .r_arrow = token.span },
            .@"<" => return Expr{ .l_arrow = token.span },
            .@"," => return Expr{ .in = token.span },
            .@"." => return Expr{ .out = token.span },
            else => return error.ParseError,
        }
    }

    fn deinit(self: Expr, allocator: std.mem.Allocator) void {
        switch (self) {
            .par => |par| {
                for (par.abstraction) |val| {
                    val.deinit(allocator);
                }
                allocator.free(par.abstraction);
            },
            else => {},
        }
    } //character of text... :(
};

test "parse" {
    //const source = "->>>>+[-<+]-.";
    const source = "+[->+]-";
    var actual = try parse(source, std.testing.allocator);
    defer actual.deinit(std.testing.allocator);

    try std.testing.expectEqualDeep(
        File{
            .expressions = &[_]Expr{
                .{
                    .plus = .{ 0, 1 },
                },
                .{
                    .par = .{
                        .open_paren = .{ 1, 2 },
                        .abstraction = &[_]Expr{
                            .{
                                .minus = .{ 2, 3 },
                            },
                            .{
                                .r_arrow = .{ 3, 4 },
                            },
                            .{
                                .plus = .{ 4, 5 },
                            },
                        },
                        .close_paren = .{ 5, 6 },
                    },
                },
                .{
                    .minus = .{ 6, 7 },
                },
            },
            .eof = .{ 7, 7 },
        },
        actual,
    );
}
