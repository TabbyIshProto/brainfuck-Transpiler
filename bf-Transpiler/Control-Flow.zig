const std = @import("std");

//temp consts
const ast = @import("bf-AbstSyntaxTree.zig");
const lxr = @import("bf-Tokeniser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const file = @embedFile("test-Programs/yeen.bf");
    const tree = try ast.parse(lxr.Lexer.create(file), lxr.Lexeme.eof, allocator);
    defer tree.free();

    std.debug.print("{}", .{tree});
}
