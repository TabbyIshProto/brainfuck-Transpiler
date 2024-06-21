const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var program = try Program.compile(",>,[-<[-<+<+>>]<[->+<]>>]<<<.", allocator);
    defer program.deinit();

    for (program.insts) |inst| {
        std.debug.print("{any}\n", .{inst});
    }
}

pub const Inst = union(enum) {
    add: u8,
    slide: isize,
    jz: usize,
    jnz: usize,
    input: void,
    output: void,
};

pub const Program = struct {
    const mem_len: usize = 0x1000;

    insts: []const Inst,
    allocator: std.mem.Allocator,
    ip: usize,
    tape: [mem_len]u8,
    ptr: usize,

    pub fn compile(source: []const u8, allocator: std.mem.Allocator) error{ InvalidProgram, OutOfMemory }!Program {
        var insts = std.ArrayList(Inst).init(allocator);
        errdefer insts.deinit();
        var openings = std.ArrayList(usize).init(allocator);
        defer openings.deinit();

        for (source) |ch| {
            switch (ch) {
                '>' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .slide) {
                            insts.items[insts.items.len - 1].slide += 1;
                            continue;
                        }
                    }
                    try insts.append(Inst{ .slide = 1 });
                },
                '<' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .slide) {
                            insts.items[insts.items.len - 1].slide -= 1;
                            continue;
                        }
                    }
                    try insts.append(Inst{ .slide = -1 });
                },
                '+' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            insts.items[insts.items.len - 1].add +%= 1;
                            continue;
                        }
                    }
                    try insts.append(Inst{ .add = 1 });
                },
                '-' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            insts.items[insts.items.len - 1].add -%= 1;
                            continue;
                        }
                    }
                    try insts.append(Inst{ .add = 0xFF });
                },
                '.' => try insts.append(Inst{ .output = {} }),
                ',' => try insts.append(Inst{ .input = {} }),
                '[' => {
                    try openings.append(insts.items.len);
                    try insts.append(Inst{ .jz = undefined });
                },
                ']' => {
                    const open = openings.popOrNull() orelse return error.InvalidProgram;
                    try insts.append(Inst{ .jnz = open + 1 });
                    insts.items[open].jz = insts.items.len;
                },
                else => return error.InvalidProgram,
            }
        }
        if (openings.items.len != 0) {
            return error.InvalidProgram;
        }

        return Program{
            .insts = try insts.toOwnedSlice(),
            .allocator = allocator,
            .ip = 0,
            .tape = [1]u8{0} ** mem_len,
            .ptr = 0,
        };
    }

    pub fn deinit(self: *Program) void {
        self.allocator.free(self.insts);
        self.* = undefined;
    }
};
