const std = @import("std");
const Allocator = std.mem.Allocator;
const Stack = std.SinglyLinkedList;
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const interpret = @import("interpret.zig");
const RockError = interpret.Error;
const RockVal = interpret.RockVal;
const RockMachine = interpret.RockMachine;

pub fn def(state: *RockMachine) !void {
    const usage = "USAGE: QUOTE TERM def ({any})\n";

    const vals = state.popN(2) catch |e| {
        try stderr.print(usage, .{e});
        return RockError.WrongArguments;
    };

    const quote = vals[0].asQuote();
    const name = vals[1].asCommand();

    if (name == null or quote == null) {
        try stderr.print(usage, .{.{ name, quote }});
        try state.pushN(2, vals);
        return RockError.WrongArguments;
    }

    try state.define(name.?, "TODO", .{ .quote = quote.? });
}

pub fn pl(state: *RockMachine) !void {
    const val = try state.pop();
    try val.print();
    try stdout.print("\n", .{});
}

pub fn dotS(state: *RockMachine) !void {
    try stdout.print("[ ", .{});

    var ctxNode = state.nest.first orelse return;

    var valNode = ctxNode.data.stack.first;
    var printOrder = Stack(RockVal){};

    while (valNode) |node| : (valNode = node.next) {
        var printNode = try state.alloc.create(Stack(RockVal).Node);
        printNode.* = Stack(RockVal).Node{ .data = node.data, .next = null };
        printOrder.prepend(printNode);
    }

    while (printOrder.popFirst()) |node| {
        try node.data.print();
        state.alloc.destroy(node);
        try stdout.print(" ", .{});
    }

    try stdout.print("]\n", .{});
}

pub fn add(state: *RockMachine) !void {
    const usage = "USAGE: a b + -> a+b ({any})\n";

    const ns = state.popN(2) catch |e| {
        try stderr.print(usage, .{e});
        return RockError.WrongArguments;
    };

    { // Both integers
        const a = ns[0].asI64();
        const b = ns[1].asI64();

        if (a != null and b != null) {
            try state.push(.{ .i64 = a.? + b.? });
            return;
        }
    }

    { // Both floats
        const a = ns[0].asF64();
        const b = ns[1].asF64();

        if (a != null and b != null) {
            try state.push(.{ .f64 = a.? + b.? });
            return;
        }
    }
}

pub fn subtract(state: *RockMachine) !void {
    const usage = "USAGE: a b - -> a+b ({any})\n";

    const ns = state.popN(2) catch |e| {
        try stderr.print(usage, .{e});
        return RockError.WrongArguments;
    };

    { // Both integers
        const a = ns[0].asI64();
        const b = ns[1].asI64();

        if (a != null and b != null) {
            try state.push(.{ .i64 = a.? - b.? });
            return;
        }
    }

    { // Both floats
        const a = ns[0].asF64();
        const b = ns[1].asF64();

        if (a != null and b != null) {
            try state.push(.{ .f64 = a.? - b.? });
            return;
        }
    }
}
