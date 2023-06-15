const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const SinglyLinkedList = std.SinglyLinkedList;
const StringHashMap = std.StringHashMap;
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const tokens = @import("tokens.zig");
const Token = tokens.Token;

const RockString = []const u8;
pub const RockDictionary = StringHashMap(RockCommand);
pub const RockStack = SinglyLinkedList(RockVal);
pub const RockNode = RockStack.Node;
pub const RockNest = SinglyLinkedList(RockStack);

pub const RockError = error{
    TooManyRightBrackets,
    CommandUndefined,
    ContextStackUnderflow,
    StackUnderflow,
    WrongArguments,
    ToDont, // Something is unimplemented
};

pub const RockMachine = struct {
    curr: RockStack,
    nest: RockNest,
    depth: u8,
    dictionary: RockDictionary,

    pub fn init(dict: RockDictionary) !RockMachine {
        return .{
            .curr = RockStack{},
            .nest = RockNest{},
            .depth = 0,
            .dictionary = dict,
        };
    }

    pub fn interpret(self: *RockMachine, tok: Token) !RockMachine {
        switch (tok) {
            .term => |cmdName| {
                var cmdRef = cmdName;
                return self.handleCmd(&cmdRef);
            },
            .left_bracket => {
                self.pushContext();
                self.depth += 1;
            },
            .right_bracket => {
                self.depth -= 1;
                if (self.depth < 0) {
                    return RockError.TooManyRightBrackets;
                }

                var quote = RockVal.ofQuote(try self.popContext());
                self.push(quote);
            },
            .bool => |b| self.push(RockVal.ofBool(b)),
            .i64 => |i| self.push(RockVal.ofI64(i)),
            .f64 => |f| self.push(RockVal.ofF64(f)),
            .string => |s| {
                var sRef = s;
                self.push(RockVal.ofString(&sRef));
            },
            .deferred_term => |cmd| {
                var cmdRef = cmd;
                self.push(RockVal.ofCommand(&cmdRef));
            },
            .none => {},
        }
        try self.debug();
        return self.*;
    }

    fn debug(self: RockMachine) !void {
        var node = self.curr.first;
        try stderr.print("CONTEXT: [ ", .{});
        while (node) |curr| : (node = curr.next) {
            try curr.data.print();
            try stderr.print(" ", .{});
        }
        try stderr.print("]\n", .{});
    }

    fn handle(self: *RockMachine, val: RockVal) anyerror!RockMachine {
        switch (val.type) {
            .command => return self.handleCmd(val.value.string),
            else => self.push(val),
        }
        return self.*;
    }

    fn handleCmd(self: *RockMachine, cmdName: *RockString) !RockMachine {
        if (self.depth > 0) {
            self.push(RockVal.ofCommand(cmdName));
            return self.*;
        }

        const cmd = self.dictionary.get(cmdName.*) orelse {
            try stderr.print("Undefined: {s}\n", .{cmdName});
            return RockError.CommandUndefined;
        };
        return cmd.run(self);
    }

    pub fn push(self: *RockMachine, val: RockVal) void {
        var node = RockNode{ .data = val };
        self.*.curr.prepend(&node);
    }

    pub fn push2(self: *RockMachine, vals: RockVal2) void {
        self.push(vals.b);
        self.push(vals.a);
    }

    pub fn pop(self: *RockMachine) !RockVal {
        const top = self.curr.popFirst() orelse return RockError.StackUnderflow;
        return top.data;
    }

    pub fn pop2(self: *RockMachine) !RockVal2 {
        const a = try self.pop();
        const b = self.pop() catch |e| {
            self.push(a);
            return e;
        };
        return .{ .a = a, .b = b };
    }

    pub fn pushContext(self: *RockMachine) void {
        var prev = self.curr;
        var node = RockNest.Node{ .data = prev };
        self.nest.prepend(&node);

        self.curr = RockStack{};
    }

    pub fn popContext(self: *RockMachine) !RockStack {
        var curr = self.curr;
        var next = self.nest.popFirst() orelse return RockError.ContextStackUnderflow;
        self.curr = next.data;
        return curr;
    }
};

// TODO: Why did union(enum) blow up?
pub const RockVal = struct {
    type: RockType,
    value: RockValue,

    pub fn ofBool(b: bool) RockVal {
        return RockVal{
            .type = .bool,
            .value = RockValue{ .bool = b },
        };
    }

    pub fn ofI64(i: i64) RockVal {
        return RockVal{
            .type = .i64,
            .value = RockValue{ .i64 = i },
        };
    }

    pub fn ofF64(f: f64) RockVal {
        return RockVal{
            .type = .f64,
            .value = RockValue{ .f64 = f },
        };
    }

    pub fn ofCommand(cmd: *RockString) RockVal {
        return RockVal{
            .type = .command,
            .value = RockValue{ .string = cmd },
        };
    }

    pub fn ofString(s: *RockString) RockVal {
        return RockVal{
            .type = .string,
            .value = RockValue{ .string = s },
        };
    }

    pub fn ofQuote(q: RockStack) RockVal {
        return RockVal{
            .type = .quote,
            .value = RockValue{ .quote = q },
        };
    }

    pub fn asBool(self: RockVal) ?bool {
        return switch (self) {
            .bool => |b| b,
            else => null,
        };
    }

    pub fn asI64(self: RockVal) ?i64 {
        return switch (self.type) {
            .i64 => self.value.i64,
            else => null,
        };
    }

    pub fn asF64(self: RockVal) ?f64 {
        return switch (self.type) {
            .f64 => self.value.f64,
            else => null,
        };
    }

    pub fn asCommand(self: RockVal) ?*RockString {
        return switch (self.type) {
            .command => self.value.string,
            else => null,
        };
    }

    pub fn asQuote(self: RockVal) ?RockStack {
        return switch (self.type) {
            .quote => self.value.quote,
            else => null,
        };
    }

    pub fn asString(self: RockVal) ?*RockString {
        return switch (self.type) {
            .string => self.value.string,
            else => null,
        };
    }

    pub fn print(self: RockVal) !void {
        switch (self.type) {
            .bool => try stdout.print("{}", .{self.value.bool}),
            .i64 => try stdout.print("{}", .{self.value.i64}),
            .f64 => try stdout.print("{}", .{self.value.f64}),
            .command => try stdout.print("\\{s}", .{self.value.string}),
            .string => try stdout.print("\"{s}\"", .{self.value.string}),
            .quote => {
                try stdout.print("[ ", .{});
                var node = self.value.quote.first;
                while (node) |n| : (node = n.next) {
                    try n.data.print();
                    try stdout.print(" ", .{});
                }
                try stdout.print("]", .{});
            },
        }
    }
};

pub const RockType = enum {
    bool,
    i64,
    f64,
    command,
    string,
    quote,
};

pub const RockValue = union {
    bool: bool,
    i64: i64,
    f64: f64,
    string: *RockString,
    quote: RockStack,
};

pub const RockVal2 = struct {
    a: RockVal,
    b: RockVal,
};

pub const RockCommand = struct {
    name: RockString,
    description: RockString,
    action: RockAction,

    fn run(self: RockCommand, state: *RockMachine) !RockMachine {
        switch (self.action) {
            .builtin => |b| return b(state),
            .quote => |q| {
                var nextState = state.*;
                var curr = q;
                while (curr.popFirst()) |val| {
                    nextState = try nextState.handle(val.data);
                }
                return nextState;
            },
        }
    }
};

pub const RockAction = union(enum) {
    builtin: *const fn (*RockMachine) anyerror!RockMachine,
    quote: RockStack,
};
