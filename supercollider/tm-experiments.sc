(
var state_bits = 3;
var symbol_bits = 3;
var move_bits = 1;
var step = 0;
var head = 0;
var state = 0;
var movements = [-1, 1];
var program_length = 1<<(state_bits+symbol_bits);
var program_width = state_bits+symbol_bits+move_bits;
var program_bits = program_length*program_width;
var tape = Dictionary.new;
var program = Int8Array.fill(program_bits.div(8)+1, {256.rand});
//Int8Array.newClear((program_bits/8).ceil);
var read_offset = {arg byte, width, offset;
    var b0 = program[byte];
    var b1 = program[byte+1];
    var mask = 0xff >> (8-width);
    var shift0 = offset+width-8;
    if (shift0>=0) {b0 << shift0} {b0 >> (0-shift0)}
     | (b1 >> (16-offset-width)) & mask
};
var get_instruction = {arg idx;
    var first_bit = idx*program_width;
    var state_byte = first_bit.div(8);
    var state_offset = first_bit - (state_byte*8);
    var symbol_byte = (first_bit+state_bits).div(8);
    var symbol_offset = first_bit + state_bits - (symbol_byte*8);
    var move_byte = (first_bit+state_bits+symbol_bits).div(8);
    var move_offset = first_bit + state_bits + symbol_bits - (move_byte*8);
    var state  = read_offset.(state_byte,  state_bits,  state_offset);
    var symbol = read_offset.(symbol_byte, symbol_bits, symbol_offset);
    var move   = read_offset.(move_byte,   move_bits,   move_offset);
    [state, symbol, move]
};
Routine {
    loop {
        var symbol = tape[head] ? 0;
        var idx = (state<<symbol_bits) | symbol;
        var new_state, new_symbol, move_idx;
        "step: % \t state: % \t symbol: % \t head: %".format(step, state, symbol, head).postln;
        # new_state, new_symbol, move_idx = get_instruction.(idx);
        tape[head] = new_symbol;
        head = head + movements[move_idx];
        state = new_state;
        step = step + 1;
        // state.yield;
        0.1.wait;
    };
}.play;

// get_instruction.(0)
// program
// state * (1<<state_bits) + 0
)