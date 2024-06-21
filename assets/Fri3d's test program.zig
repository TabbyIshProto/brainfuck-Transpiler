const std = @import("std");

pub fn main() !void {
    var program = try ProgramState.new(",>,[-<[-<+<+>>]<[->+<]>>]<<<.");
    while (program.tick() != ProgramState.IsDone.done) {}
}

pub const ProgramState = struct {
    const mem_len: usize = 0x100000;

    source: []const u8,
    ip: usize,
    tape: [mem_len]u8,
    ptr: usize,

    pub fn new(code: []const u8) error{InvalidProgram}!ProgramState {
        if (std.mem.indexOfNone(u8, code, "><+-.,[]") != null) {
            return error.InvalidProgram;
        }
        var count: usize = 0;
        for (code) |ch| {
            switch (ch) {
                '[' => count += 1,
                ']' => {
                    if (count == 0) {
                        return error.InvalidProgram;
                    } else {
                        count -= 1;
                    }
                },
                else => {},
            }
        }
        if (count != 0) {
            return error.InvalidProgram;
        }

        return ProgramState{
            .source = code,
            .ip = 0,
            .tape = [1]u8{0} ** mem_len,
            .ptr = 0,
        };
    }

    pub const IsDone = enum { done, not_done };

    pub fn tick(self: *ProgramState) IsDone {
        if (self.ip >= self.source.len) {
            return IsDone.done;
        }

        const inst = self.source[self.ip];
        defer self.ip += 1;
        switch (inst) {
            '>' => {
                self.ptr += 1;
                self.ptr %= mem_len;
            },
            '<' => {
                self.ptr += mem_len - 1;
                self.ptr %= mem_len;
            },
            '+' => self.tape[self.ptr] +%= 1,
            '-' => self.tape[self.ptr] -%= 1,
            '.' => std.io.getStdOut().writeAll(&[1]u8{self.tape[self.ptr]}) catch {},
            ',' => {
                var buffer: [1]u8 = [1]u8{0};
                _ = std.io.getStdIn().readAll(&buffer) catch 0;
                self.tape[self.ptr] = buffer[0];
            },
            '[' => if (self.tape[self.ptr] == 0) {
                self.ip = search(self.source, self.ip, .forward);
            },
            ']' => if (self.tape[self.ptr] != 0) {
                self.ip = search(self.source, self.ip, .backward);
            },
            else => unreachable,
        }

        return IsDone.not_done;
    }

    const Direction = enum { forward, backward };

    fn search(source: []const u8, begin: usize, direction: Direction) usize {
        var loc: usize = begin;
        var count: isize = 0;
        while (true) {
            switch (source[loc]) {
                '[' => count += 1,
                ']' => count -= 1,
                else => {},
            }
            if (count == 0) break;
            switch (direction) {
                Direction.forward => loc += 1,
                Direction.backward => loc -= 1,
            }
        }
        return loc;
    }
};

test "search" {
    for (
        [_][]const u8{ "[++[-]-+]+", "[<<>>[--+[+],,.]-]..." },
        [_]usize{ 0, 15 },
        [_]ProgramState.Direction{ .forward, .backward },
        [_]usize{ 8, 5 },
    ) |source, begin, direction, expected| {
        try std.testing.expectEqual(
            expected,
            ProgramState.search(source, begin, direction),
        );
    }
}
