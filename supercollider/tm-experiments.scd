
// this version with Int32Array should be more elegant
// but +>> is broken? https://github.com/supercollider/supercollider/issues/5607
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
var program = Int32Array.fill(program_bits.div(32)+1, {0x7fffffff.rand2});
var read_offset = {arg word, width, offset;
    var w0 = program[word];
    var w1 = program[word+1];
    var mask_shift = 32 - width;
    var mask = 0xffffffff +>> mask_shift;
    var shift0 = mask_shift - offset;
    var shift1 = shift0 + 32;
    (
        (w0 +>> shift0) | (w1 +>> shift1)
    ) & mask
};
var get_instruction = {arg state, symbol;
    var idx = (state<<symbol_bits) | symbol;
    var state_bit = idx*program_width;
    var state_word = state_bit.div(32);
    var state_offset = state_word - (state_word*32);
    var symbol_bit = state_bit + state_bits;
    var symbol_word = symbol_bit.div(32);
    var symbol_offset = symbol_bit - (symbol_word*32);
    var move_bit = symbol_bit + symbol_bits;
    var move_word = move_bit.div(32);
    var move_offset = move_bit - (move_word*32);
    var new_state  = read_offset.(state_word,  state_bits,  state_offset);
    var new_symbol = read_offset.(symbol_word, symbol_bits, symbol_offset);
    var move_idx   = read_offset.(move_word,   move_bits,   move_offset);
    [new_state, new_symbol, move_idx]
};
Routine {
    loop {
        var symbol = tape[head] ? 0;
        var new_state, new_symbol, move_idx, move;
        "step: % \t state: % \t symbol: % \t head: %".format(step, state, symbol, head).postln;
        # new_state, new_symbol, move_idx = get_instruction.(state, symbol);
        // move = movements[move_idx];
        move = if(symbol==0){0-head.sign}{movements[move_idx]};
        new_symbol = if(new_symbol==0){1}{new_symbol};
        tape[head] = new_symbol;
        head = head + move;
        state = new_state;
        step = step + 1;
        0.1.wait;
    };
}.play;
)



(
var state_bits = 3;
var symbol_bits = 4;
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
    var mask = (0xff >> (8 - width));
    (
        ((b0 & 0xff) << (offset + width - 8))
        | ((b1 & 0xff) >> (16 - offset - width))
    ) & mask
};
var get_instruction = {arg state, symbol;
    var idx = (state<<symbol_bits) | symbol;
    var state_bit = idx*program_width;
    var state_byte = state_bit.div(8);
    var state_offset = state_bit - (state_byte*8);
    var symbol_bit = state_bit + state_bits;
    var symbol_byte = symbol_bit.div(8);
    var symbol_offset = symbol_bit - (symbol_byte*8);
    var move_bit = symbol_bit + symbol_bits;
    var move_byte = move_bit.div(8);
    var move_offset = move_bit - (move_byte*8);
    var new_state  = read_offset.(state_byte,  state_bits,  state_offset);
    var new_symbol = read_offset.(symbol_byte, symbol_bits, symbol_offset);
    var move_idx   = read_offset.(move_byte,   move_bits,   move_offset);
    [new_state, new_symbol, move_idx]
};

// get_instruction.(0, 1).postln;
// program[0].asBinaryDigits.postln;
// program[1].asBinaryDigits.postln;

var synth = {Splay.ar(
    Formant.ar(\freq.kr(100, 0.02), \formant.kr(512, 0.1), mul:\gain.kr(0.1, 0.3)),
    center:\center.kr(0.5)
)}.play;

Routine {
    0.1.wait;
    synth.set(\center, 2.0.rand-1);
    loop {
        var symbol = tape[head] ? 0;
        var new_state, new_symbol, move_idx, move;
        "step: % \t head: % \t state: % \t symbol: %".format(step, head, state, symbol).postln;
        # new_state, new_symbol, move_idx = get_instruction.(state, symbol);

        // tricks to get more interesting machines:
        move = if(symbol==0){0-head.sign}{movements[move_idx]}; //symbol zero move -> center
        // new_symbol = if(new_symbol==0){1}{new_symbol}; // 0 is never written
        // move = movements[move_idx];

        tape[head] = new_symbol;
        head = head + move;
        state = new_state;
        step = step + 1;
        synth.set(
            \freq, 75 * [1, 3/2, 5/4, 2, 4/3, 5/3, 9/8, 15/8][symbol>>1] * (2**(symbol&1)),
            //\freq, 50*(symbol+1),
            \formant, 2**(head /8 / (head.abs /8 + 1) * 5 + 9),
            \gain, 2**(-0.002*head*head)*0.2
        );
        (2**(state>>1) * 0.02 * if((state&1)==0){1.5}{1}).wait;
    };
}.play;
)