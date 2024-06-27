const std = @import("std");
const rl = @import("raylib");

const Alloc = std.mem.Allocator;

pub fn main() !void {
    std.debug.print("UwU x3 you're now gay\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    //var program = try Program.compile(",>,[-<[-<+<+>>]<[->+<]>>]<<<.", allocator);
    var program = try Program.compile(Typ.strict, @embedFile("mandelbrot.bf"), allocator);
    //var program = try Program.compile(Typ.all_extentions, "4++++++++.>6+++++.+++++++..+++.>2.>5+++++++.<<.+++.>>>7----.>6++++.>2+.>1------.", allocator);
    //var program = try Program.compile(Typ.all_extentions, @embedFile("test.bf"), allocator);
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

pub const Move = struct {
    const y_len = Program.mem_len_y;

    tape_ptrs: [y_len]i32 = [1]i32{0} ** y_len,
    raise: i8,

    pub fn init(height: u8, offset: i16) Move {
        var arr = [1]i32{0} ** y_len;
        arr[height] = offset;
        return Move{
            .tape_ptrs = arr,
            .raise = 0,
        };
    }

    pub fn slide(self: *Move, pointer: u8, amount: i32) void {
        self.tape_ptrs[pointer] += amount;
    }

    pub fn isEmpty(self: *const Move) bool {
        return std.mem.eql(i32, &self.tape_ptrs, &[1]i32{0} ** y_len);
    }
};

pub const Ist = union(enum) {
    add: u8,
    move: Move, //make u16 +%= -%=

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
    const mem_len_y: u8 = 4;

    allocator: std.mem.Allocator,
    instr: []const Ist,
    ip: usize,

    grid: [mem_len_y][mem_len_x]u8, //TODO: make this not a 2d coordinate system but independant tapes.
    tx_ptr: [mem_len_y]usize,
    ty_ptr: u8,

    pub fn compile(program_type: Typ, source_slice: []const u8, allocator: Alloc) error{ _lexingFailiure_, _InvalidProgram_, OutOfMemory }!Program {
        if (program_type == Typ.strict) return if (std.mem.indexOfNone(u8, source_slice, "+-><[],. \n\t\r") == null)
            gen_intermediate(source_slice, allocator)
        else
            error._InvalidProgram_;

        const intr_rep = try gen_intermediate(source_slice, allocator);
        return intr_rep;
        // lexical analysis, syntax analysis, semantic analysis, intermediate representation generator, code optimiser, target code generator [JIT compiler [x86 asm]] or direct translation.
    }

    pub fn gen_intermediate(slice: []const u8, allocator: std.mem.Allocator) error{ _InvalidProgram_, OutOfMemory }!Program {
        var inst_list = std.ArrayList(Ist).init(allocator);
        errdefer inst_list.deinit();

        var open_brackets = std.ArrayList(usize).init(allocator);
        defer open_brackets.deinit();

        //const checks = struct {
        //    const list_ref: *std.ArrayList = undefined;
        //
        //    fn set_ref(reference: *std.ArrayList) void {
        //        @This().list_ref = reference;
        //    }
        //
        //    fn compute(ist: Ist) bool {
        //        if (list_ref.*.getLastOrNull()) |inst| {
        //            if (inst == ist) {
        //               return true;
        //            } else return false;
        //        }
        //    }
        //};

        for (slice) |char| {
            var cur_height: u2 = 0;
            switch (char) {
                '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                    const imm = (char - '0') * 0x10;
                    try inst_list.append(Ist{ .set = imm }); //either set or add
                },
                '^' => {
                    cur_height +%= 1;
                    if (inst_list.getLastOrNull()) |inst| {
                        if (inst == .move) {
                            inst_list.items[inst_list.items.len - 1].move.raise += 1;
                            continue;
                        }
                    }
                    try inst_list.append(Ist{ .move = Move{ .raise = 1 } });
                },
                'v' => {
                    cur_height -%= 1;
                    if (inst_list.getLastOrNull()) |inst| {
                        if (inst == .move) {
                            inst_list.items[inst_list.items.len - 1].move.raise -= 1;
                            continue;
                        }
                    }
                    try inst_list.append(Ist{ .move = Move{ .raise = -1 } });
                },
                '<', '>' => {
                    const offset: i16 = 0 - ('=' - char);
                    if (inst_list.getLastOrNull()) |inst| {
                        if (inst == .move) {
                            inst_list.items[inst_list.items.len - 1].move.slide(cur_height, offset);
                            if (inst_list.items[inst_list.items.len - 1].move.isEmpty()) _ = inst_list.pop();
                            continue;
                        }
                    }
                    try inst_list.append(Ist{ .move = Move.init(cur_height, offset) });
                },
                '+' => {
                    if (inst_list.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            inst_list.items[inst_list.items.len - 1].add +%= 1;
                            continue;
                        }
                    }
                    try inst_list.append(Ist{ .add = 1 });
                },
                '-' => {
                    if (inst_list.getLastOrNull()) |inst| {
                        if (inst == .add) {
                            inst_list.items[inst_list.items.len - 1].add -%= 1;
                            continue;
                        }
                    }
                    try inst_list.append(Ist{ .add = 0xFF });
                },
                '.' => try inst_list.append(Ist{ .output = {} }),
                ',' => try inst_list.append(Ist{ .input = {} }),
                '[' => {
                    try open_brackets.append(inst_list.items.len);
                    try inst_list.append(Ist{ .jz = undefined });
                },
                ']' => {
                    const open = open_brackets.popOrNull() orelse return error._InvalidProgram_;
                    try inst_list.append(Ist{ .jnz = open + 1 });
                    inst_list.items[open].jz = inst_list.items.len;
                },
                '0' => try inst_list.append(Ist{ .set = 0 }),
                //else => return error._InvalidProgram_,
                else => {},
            }
        }
        if (open_brackets.items.len != 0) {
            return error._InvalidProgram_;
        }

        return Program{
            .allocator = allocator,
            .instr = try inst_list.toOwnedSlice(),
            .ip = 0,

            .grid = [1][mem_len_x]u8{[1]u8{0} ** mem_len_x} ** mem_len_y,
            .tx_ptr = [1]usize{0} ** mem_len_y,
            .ty_ptr = 0,
        };
    }

    pub fn deinit(self: *Program) void {
        self.allocator.free(self.instr);
        self.* = undefined;
    }

    pub fn tick(self: *Program) bool {
        if (self.ip >= self.instr.len) return false;
        const yx = self.tx_ptr[self.ty_ptr];
        switch (self.instr[self.ip]) {
            .add => |num| {
                self.grid[self.ty_ptr][yx] +%= num;
            },
            .move => |amount_union| {
                for (amount_union.tape_ptrs, 0..) |offset, idx| {
                    const x_ptr: isize = @intCast(self.tx_ptr[idx]);
                    self.tx_ptr[idx] = @intCast(@mod(x_ptr + offset, mem_len_x));
                }
                const y_ptr: i8 = @intCast(self.ty_ptr);
                self.ty_ptr = @intCast(@mod(y_ptr + amount_union.raise, mem_len_y));
            },
            .output => {
                const buf = [1]u8{self.grid[self.ty_ptr][yx]};
                std.io.getStdOut().writeAll(&buf) catch {};
            },
            .input => {
                var buf = [1]u8{0};
                _ = std.io.getStdIn().readAll(&buf) catch 0;
                self.grid[self.ty_ptr][yx] = buf[0];
            },
            .set => |imm| {
                self.grid[self.ty_ptr][yx] = imm;
            },
            .jz => |adress| if (self.grid[self.ty_ptr][yx] == 0) {
                self.ip = adress;
                return true;
            },
            .jnz => |adress| if (self.grid[self.ty_ptr][yx] != 0) {
                self.ip = adress;
                return true;
            },
            else => unreachable,
        }
        self.ip += 1;
        return true;
    }
};

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
