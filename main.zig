const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    std.debug.print("UwU x3 you're now gay\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    //var program = try Program.compile(",>,[-<[-<+<+>>]<[->+<]>>]<<<.", allocator);
    var program = try Program.compile(Typ.strict, @embedFile("mandelbrot.bf"), allocator);
    //var program = try Program.compile(Typ.all_extentions, "4++++++++.>6+++++.+++++++..+++.>2.>5+++++++.<<.+++.>>>7----.>6++++.>2+.>1------.", allocator);
    defer program.deinit();
    while (program.tick()) {}

    if (reasons_to_want_to_test_raylib() > 2) {
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
}
pub fn reasons_to_want_to_test_raylib() u8 {
    return 0;
}

pub const Typ = enum {
    strict, //no comments or other characters allowed besides +-><[]., <still ignores whitespace tho>
    default, //sees any other char as comment and allows for //, / and # comment types to include +-><[]., chars in them
    all_extentions, //initialisers, halts, 2d band /grid of cells, macros, and all fancy things all enabled
};

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

    fn add(self: *Offset, val: Offset) void {
        self.x += val.x; // this WAS the issue.
        self.y += val.y;
    }
};

pub const Ist = union(enum) {
    add: u8,
    slide: Offset,
    jz: usize,
    jnz: usize,
    input: void,
    output: void,
    set: u8,

    sentinel: void,
    system: [*]const Ist, // avoid problem of tagged union storage using pointers
};

pub const Program = struct {
    const mem_len_x: usize = 0x1000;
    const mem_len_y: u8 = 5;

    allocator: std.mem.Allocator,
    instr: []const Ist,
    ip: usize,

    grid: [mem_len_y][mem_len_x]u8,
    tx_ptr: usize,
    ty_ptr: u8,

    fn debug_program(slice: []const u8) error{_InvalidProgram_} {
        std.debug.print("Things go wrong at this locaiton: {}", .{std.mem.indexOfNone(u8, slice, "+-><[],. \n\t")});
        return error._InvalidProgram_;
    }

    pub fn compile(program_type: Typ, source_slice: []const u8, allocator: std.mem.Allocator) error{ _InvalidProgram_, OutOfMemory }!Program {
        if (program_type == Typ.strict) return if (std.mem.indexOfNone(u8, source_slice, "+-><[],. \n\t") == null) gen_intermediate(source_slice, allocator) else debug_program(source_slice);

        const intr_rep = try gen_intermediate(source_slice, allocator);
        return intr_rep;
        // lexical analysis, syntax analysis, semantic analysis,intermediate representation generator, code optimiser, target code generator [JIT compiler [x86 asm]] or direct translation.
        //TODO: lexer [tokenisation].
        // this ^^ is done using slices which are allocated.

    }

    fn gen_intermediate(slice: []const u8, allocator: std.mem.Allocator) error{ _InvalidProgram_, OutOfMemory }!Program {
        var insts = std.ArrayList(Ist).init(allocator);
        errdefer insts.deinit();

        var open_brackets = std.ArrayList(usize).init(allocator);
        defer open_brackets.deinit();

        const cur_inst = undefined;
        _ = cur_inst;
        for (slice) |char| {
            switch (char) {
                '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                    const imm = (char - '0') * 0x10;
                    try insts.append(Ist{ .set = imm }); //either set or add
                },
                'v', '^', '<', '>' => {
                    const direction = Offset.from_char(char);
                    if (insts.getLastOrNull()) |inst| {
                        //std.debug.print("{}\n", .{inst});
                        if (inst == .slide) {
                            insts.items[insts.items.len - 1].slide.add(direction);
                            if (eql(inst, Offset{ .x = 0, .y = 0 })) {
                                _ = insts.pop();
                            }
                            continue;
                        }
                    }
                    try insts.append(Ist{ .slide = direction });
                },
                '+' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            insts.items[insts.items.len - 1].add +%= 1;
                            continue;
                        }
                    }
                    try insts.append(Ist{ .add = 1 });
                },
                '-' => {
                    if (insts.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            insts.items[insts.items.len - 1].add -%= 1;
                            continue;
                        }
                    }
                    try insts.append(Ist{ .add = 0xFF });
                },
                '.' => try insts.append(Ist{ .output = {} }),
                ',' => try insts.append(Ist{ .input = {} }),
                '[' => {
                    try open_brackets.append(insts.items.len);
                    try insts.append(Ist{ .jz = undefined });
                },
                ']' => {
                    const open = open_brackets.popOrNull() orelse return error._InvalidProgram_;
                    try insts.append(Ist{ .jnz = open + 1 });
                    insts.items[open].jz = insts.items.len;
                },
                '0' => try insts.append(Ist{ .set = 0 }),
                //else => return error._InvalidProgram_,
                else => {},
            }
        }
        if (open_brackets.items.len != 0) {
            return error._InvalidProgram_;
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
            else => unreachable,
        }
        self.ip += 1;
        return true;
    }
};

pub fn eql(first: Ist, second: Offset) bool {
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
    const yeet = Ist{ .slide = Offset{ .x = 0, .y = 0 } };
    const boo = eql(yeet, Offset{ .x = 0, .y = 0 });
    std.debug.print("the tagged unions match: {}\n", .{boo});
}

test "ternary" {
    var itr: u8 = 5;
    const let = 5;

    itr = if (let < 6) 10 else 15;
    itr = 30 + if (let <= 7) 17 else 0;
    std.debug.print("yeen has done: '{}' laps around the pole due to zoomies\n", .{itr});
}

test "negation" {
    var n: u8 = 30;
    n = ~n + 1;
    std.debug.print("the inverse of 30 <256 - 30> is: {}\n", .{n});
}
// step 1: lexer, ignores whitespace, comments and divies up a program into its tokens.
//
//
//
//
//
