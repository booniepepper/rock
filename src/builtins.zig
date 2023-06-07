const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const interpret = @import("interpret.zig");
const RockError = interpret.RockError;
const RockDictionary = interpret.RockDictionary;
const RockCommand = interpret.RockCommand;
const RockAction = interpret.RockAction;
const RockMachine = interpret.RockMachine;

pub fn def(state: *RockMachine) !RockMachine {
    const usage = "USAGE: QUOTE TERM def\n";

    const vals = state.pop2() catch {
        try stderr.print(usage, .{});
        return state.*;
    };

    const name = vals.a.asCommand();
    const quote = vals.b.asQuote();

    if (name == null or quote == null) {
        try stderr.print(usage, .{});
        state.push2(vals);
        return RockError.WrongArguments;
    }

    try state.dictionary.put(name.?, RockCommand{
        .name = name.?,
        .description = "TODO",
        .action = RockAction{
            .quote = quote.?,
        },
    });

    return state.*;
}

pub fn pl(state: *RockMachine) !RockMachine {
    const val = try state.pop();
    try stdout.print("{any}\n", .{val});
    return state.*;
}