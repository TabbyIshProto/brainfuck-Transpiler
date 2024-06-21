const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    std.debug.print("UwU x3 you're now gay\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    //var program = try Program.compile(",>,[-<[-<+<+>>]<[->+<]>>]<<<.", allocator);
    //var program = try Program.compile(@embedFile("mandelbrot.bf"), allocator);
    var program = try Program.compile(">^<v", allocator);
    defer program.deinit();
    while (program.tick()) {}

    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "Title");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
        const fontsize: i32 = 20;
        var i: i32 = 0;
        while (i < 137) : (i += 1) {
            //rl.drawPixel(posX: i32, posY: i32, color: Color)
            rl.drawText("U", @mod(i * (fontsize - 4), screenWidth), @divFloor(i * (fontsize - 4), screenWidth) * (fontsize - 4), fontsize, rl.Color.violet);
        }
        rl.drawText("Congrats! You created your first window!", 190, 200, 20, rl.Color.light_gray);
    }
}

pub const Offset = struct {
    x: i32 = 0,
    y: i32 = 0,

    fn from_char(char: u8) Offset {
        return switch (char) {
            'v' => Offset{ .y = -1 },
            '^' => Offset{ .y = 1 },
            '>' => Offset{ .x = 1 },
            '<' => Offset{ .x = -1 },
            else => unreachable,
        };
    }

    fn add(self: Offset, val: Offset) void {
        self.x += val.x; // this is the issue
        self.y += val.y;
    }
};

pub const Inst = union(enum) {
    add: u8,
    slide: Offset,
    jz: usize,
    jnz: usize,
    input: void,
    output: void,
    set: u8,
};

pub const Program = struct {
    const mem_len_x: usize = 0x1000;
    const mem_len_y: u8 = 5;

    allocator: std.mem.Allocator,
    instr: []const Inst,
    ip: usize,

    grid: [mem_len_y][mem_len_x]u8,
    tx_ptr: usize,
    ty_ptr: u8,

    pub fn compile(source_slice: []const u8, allocator: std.mem.Allocator) error{ InvalidProgram, OutOfMemory }!Program {
        var insts = std.ArrayList(Inst).init(allocator);
        errdefer insts.deinit();
        var openings = std.ArrayList(usize).init(allocator);
        defer openings.deinit();

        const simple_replacement_slice = try allocator.alloc(u8, std.mem.replacementSize(u8, source_slice, "[-]", "0"));
        defer allocator.free(simple_replacement_slice);
        _ = std.mem.replace(u8, source_slice, "[-]", "0", simple_replacement_slice);

        //TODO: lexer [tokenisation].
        // this ^^ is done using slices which are allocated.

        const cur_inst: *Inst = &insts.items[insts.items.len - 1];
        for (simple_replacement_slice) |char| {
            switch (char) {
                'v', '^', '<', '>' => {
                    std.debug.print("any '>^<v' is read\n", .{});
                    const direction = Offset.from_char(char);
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .slide) {
                            std.debug.print("only one is read due to the get last returning null the first time\n", .{});
                            cur_inst.slide.add(direction); //this statement is the issue.
                            std.debug.print("reached", .{});
                            if (eql(inst, Offset{ .x = 0, .y = 0 })) {
                                _ = insts.pop();
                                std.debug.print("EEEEEEEEEEEEEEEEEEEEEEEEEEE", .{});
                            }
                            continue;
                        }
                    }
                    try insts.append(Inst{ .slide = direction });
                },
                '+' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            cur_inst.add +%= 1;
                            continue;
                        }
                    }
                    try insts.append(Inst{ .add = 1 });
                },
                '-' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            cur_inst.add -%= 1;
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
                '0' => try insts.append(Inst{ .set = 0 }),
                //else => return error.InvalidProgram,
                else => {},
            }
        }
        if (openings.items.len != 0) {
            return error.InvalidProgram;
        }

        return Program{
            .allocator = allocator,
            .instr = try insts.toOwnedSlice(),
            .ip = 0,

            .grid = [1][mem_len_x]u8{[1]u8{0} ** mem_len_x} ** mem_len_y,
            .tx_ptr = 0,
            .ty_ptr = 0,
        };
    }

    pub fn deinit(self: *Program) void {
        self.allocator.free(self.instr);
        self.* = undefined;
    }

    pub fn tick(self: *Program) bool {
        if (self.ip >= self.instr.len) return false;
        switch (self.instr[self.ip]) {
            .add => |num| {
                self.grid[self.ty_ptr][self.tx_ptr] +%= num;
            },
            .slide => |amount| {
                const x_ptr: isize = @intCast(self.tx_ptr);
                const y_ptr: isize = @intCast(self.ty_ptr);
                self.tx_ptr = @intCast(@mod(x_ptr + amount.x, mem_len_x)); // self optimises when compiling.
                self.ty_ptr = @intCast(@mod(y_ptr + amount.y, mem_len_y));
            },
            .output => {
                const buf = [1]u8{self.grid[self.ty_ptr][self.tx_ptr]};
                std.io.getStdOut().writeAll(&buf) catch {};
            },
            .input => {
                var buf = [1]u8{0};
                _ = std.io.getStdIn().readAll(&buf) catch 0;
                self.grid[self.ty_ptr][self.tx_ptr] = buf[0];
            },
            .set => |imm| {
                self.grid[self.ty_ptr][self.tx_ptr] = imm;
            },
            .jz => |adress| if (self.grid[self.ty_ptr][self.tx_ptr] == 0) {
                self.ip = adress;
                return true;
            },
            .jnz => |adress| if (self.grid[self.ty_ptr][self.tx_ptr] != 0) {
                self.ip = adress;
                return true;
            },
        }
        self.ip += 1;
        return true;
    }
};

pub fn eql(first: Inst, second: Offset) bool {
    switch (first) {
        .slide => if (first.slide.x == second.x and first.slide.y == second.y) return true,
        else => {},
    }
    return false;
}
// ",>,[-<[-<+<+>>]<[->+<]>>]<<<."
//test "Create &Write-to file" {
//    const file = try std.fs.cwd().createFile("output.txt", .{ .read = true });
//    defer file.close();
//
//    const bytes_written = try file.writeAll("hello UwU x3");
//    _ = bytes_written;
//
//    var buffer: [100]u8 = undefined;
//    try file.seekTo(0);
//    const bytes_read = try file.readAll(&buffer);
//    _ = bytes_read;
//}

test "type_test" {
    const yeet = Inst{ .slide = Offset{ .x = 0, .y = 0 } };
    const boo = eql(yeet, Offset{ .x = 0, .y = 0 });
    std.debug.print("the tagged unions match: {}\n", .{boo});
}

// step 1: lexer, ignores whitespace, comments and divies up a program into its tokens.
//
//
//
//
//
