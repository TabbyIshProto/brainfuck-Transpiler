const std = @import("std");
const lxr = @import("bf-Tokeniser.zig");

// file ::= expr* eof
// expr ::= "+" | "-" | ">" | "<" | "," | "." | "[" expr* "]"

const ParseError = error{
    _InvalidProgram_,
};
