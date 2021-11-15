s.boot
s.quit

// TODO:
//    recording interface
//    pitch/rhythm features
//    cmd .
//    OO refactor
//    master compressor / auto ducking mixer?
//    fancy pans?

//    visualizer (for finding loops especially?)
//    more program features?
//      tape features?
//    better sampler?

(
~max_frames = s.sampleRate * 10;
~n_channels = 1;
// ~soundbuf = Buffer.alloc(s, ~max_frames, ~n_channels);
~sound_in = 0;
~node_data = Dictionary.new;
~node_cond = Dictionary.new;
SynthDef(\recorder, { arg inbus, soundbuf, databuf;
    var input = SoundIn.ar(inbus, ~n_channels);
    var stop = T2A.ar(\stop.tr(0));
    var phase = Phasor.ar(
        1, BufRateScale.kr(soundbuf), start:0, end:BufFrames.kr(soundbuf));
    Demand.ar(stop, 0, Dbufwr(phase, databuf, 0));
    SendTrig.ar(stop, 0, phase);
    BufWr.ar(input, soundbuf, phase, loop: 0);
}).add;
OSCdef(\record_length, { arg msg, time;
    var path, node_id, trig_id, val;
    # path, node_id, trig_id, val = msg;
    // [\OSC, time, node_id, trig_id, val].postln;
    // ~node_data[node_id] ?? {~node_data[node_id]=Dictionary.new};
    // ~node_data[node_id][\length] = val;
    // ~node_data.postln;
    ~node_data[node_id] = val;
    ~node_cond.postln[node_id.postln].postln.signalOne;
},'/tr', s.addr);
)

// OSCFunc.trace;

(
var soundbuf = ~lastsoundbuf = Buffer.alloc(s, ~max_frames, ~n_channels);
var databuf = Buffer.alloc(s, 1);
var featbuf = ~lastfeatbuf = Buffer.new;
var statsbuf = ~laststatsbuf = Buffer.new;
var state_bits = 5;
var symbol_bits = 5;
var move_bits = 1;
var step = 0;
var head = 0;
var state = 0;
var movements = [-1, 1];
var program_length = 1<<(state_bits+symbol_bits);
var program_width = state_bits+symbol_bits+move_bits;
var program_bits = (program_length*program_width);//.postln;
var program_bytes = (program_bits/8).ceil.div(1);
var tape = Dictionary.new;
var program;

var mel_bands = 100;
var n_moments = 7; // max 4 (7)
var n_derivs = 2;

// start recording
var rec = Synth(\recorder, [inbus: ~sound_in, soundbuf:soundbuf, databuf:databuf]);
var node_id = rec.nodeID.postln;
var sound_length;

var read_offset = {arg byte, width, offset;
    var err = if(byte>=program_bytes) {"program out of bounds at %".format(byte).postln};
    var b0 = program[byte];
    var b1 = program[byte+1]; //program storage should have an extra byte?
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

var get_program = {
    //loadToFloatArray seems to block???
    // var cond = CondVar.new;

    var quantize = {
        arg val, levels, floor = -13, range = 10;
        ((val - floor).clip(0, range-1e-7)/range*levels).div(1)
    };

    program = Int8Array.newClear(program_bits.div(8)+4);

    //start of audio -> program
    /*soundbuf.loadToFloatArray(0, program_bits.div(32)+1, {
        arg arr;
        arr.do{ arg val, idx;
            var bin = val.as32Bits;//.postln;
            var pidx = idx*4;
            program[pidx] = (bin >> 24) & 0xff;
            program[pidx+1] = (bin >> 16) & 0xff;
            program[pidx+2] = (bin >> 8) & 0xff;
            program[pidx+3] = bin & 0xff;
        };
    });*/

    // multichannel buffers come back channel-first (frame locality)

    //mfcc stats -> program

    //quantize to program_width so 1 stat per instruction
    //this would work for a "sparse" Int32 program format:
    // "% stats vs % instructions".format(n_moments*(n_derivs+1)*mel_bands, program_length).postln;
    /*statsbuf.loadToFloatArray(0, program_length, {
        arg arr;
        var pidx = 0;
        var levels = 2**program_width;
        (n_derivs+1).do{
            arg deriv;
            7.do{
                arg moment;
                if (moment < n_moments){mel_bands.do{
                    arg coef;
                    var idx = coef + (mel_bands*(moment + 7*deriv));
                    var stat = arr[idx];
                    program[pidx] = quantize.(stat, levels, floor:-20, range:60).postln;
                    pidx = pidx+1;
                }}
            }
        }
    });*/
    "% stats vs % bytes".format(n_moments*(n_derivs+1)*mel_bands, program_bits.div(8)).postln;
    // (statsbuf.numFrames*statsbuf.numChannels).postln;
    statsbuf.loadToFloatArray(0, program_length, {
        arg arr;
        var pidx = 0;
        (n_derivs+1).do{
            arg deriv;
            7.do{
                arg moment;
                if (moment < n_moments){mel_bands.do{
                    arg coef;
                    var idx = coef + (mel_bands*(moment + 7*deriv));
                    var stat = arr[idx];
                    if(pidx < program_bits.div(8)){
                        program[pidx] = quantize.(stat.abs, 256, floor:0, range:60);//.postln;
                    };
                    pidx = pidx+1;
                }}
            }
        }
    });


    // quantize temporal features -> tape
    /*featbuf.loadToFloatArray(0, sound_length.div(512),  {
        arg arr;
        var n_symbols = 2**symbol_bits;
        // "feature array:".postln;
        // arr.dump;
        arr.do{ arg val, idx;
            tape[idx] = quantize.((val+1e-7).log2, n_symbols)//.postln
        };
    });*/

    // program.dump
    // program.reverse[0].postln;


};


var synth = {
    var frames = BufRd.ar(1, databuf, DC.ar(0), interpolation:1);
    var phase = Phasor.ar(0, (frames>0)*\rate.kr(100, 0.02)*BufRateScale.kr(soundbuf), 0, frames);
    var sound = BufRd.ar(1, soundbuf, phase);
    Splay.ar(
        Formlet.ar(
            sound,
            \formant.kr(512, 0.1),
            0.001, 0.005,
            mul: \gain.kr(0.1, 0.3)),
    center:\center.kr(0.5)
)}.play;//.run(false);

var intervals = [1, 3/2, 5/4, 2, 4/3, 5/3, 9/8, 15/8];

~node_cond[node_id] = CondVar.new;

Routine {
    //  record for 1 second. TODO: instead block waiting for a control
    0.5.wait;
    rec.set(\stop, 1);
    ~node_cond[node_id].wait;
    sound_length = ~node_data[node_id];
    rec.free;

    \stopped.postln;

    // databuf.get(0, {arg val; l=val});
    // l.postln;
    // ~node_data.postln;


    //TODO: fluidbufchroma - for scale
    //      fluidbufampslice (noveltyslice? onsetslice?) - for sampler and timing
    //      pitch, mfcc, spectralshape etc - for program and tape
    // not sure if flucoma can do rhythm-rate spectral stuff on features?

    FluidBufMFCC.process(s, soundbuf, 0, sound_length, features:featbuf,
        numBands:mel_bands, numCoeffs:mel_bands, action:{~node_cond[node_id].signalOne});
    ~node_cond[node_id].wait;

    FluidBufStats.process(s, featbuf, 0, featbuf.numFrames, stats:statsbuf,
        numDerivs:n_derivs, action:{~node_cond[node_id].signalOne});
    ~node_cond[node_id].wait;

    \features.postln;

    //ok is this really the best way to wait on the server, using condvar:
    // flucoma blessedly has a blocking method (it  doesn't quite work though...?)
    // FluidBufMelBands.process(s, soundbuf, 0, ~node_data[node_id], features:featbuf,
        // action:{~node_cond[node_id].signalOne});
        // ~node_cond[node_id].wait;

    // program = Int8Array.fill(program_bits.div(8)+1, {256.rand});
    get_program.value;

    \program.postln;

    synth.set(\center, 2.0.rand-1).postln;

    // 1.wait;

    // s.makeBundle(1, {rec.free});

    loop {
        var symbol = tape[head] ? 0;
        var new_state, new_symbol, move_idx, move;
        // "step: % \t head: % \t state: % \t symbol: %".format(step, head, state, symbol).postln;
        # new_state, new_symbol, move_idx = get_instruction.(state, symbol);

        // tricks to get more interesting machines:
        move = if(symbol==0){0-head.sign}{movements[move_idx]}; //symbol zero move -> center
        // new_symbol = if(new_symbol==0){1}{new_symbol}; // 0 is never written
        // move = movements[move_idx];

        if (new_symbol!=0) {tape[head] = new_symbol};
        head = head + move;
        state = new_state;
        step = step + 1;
        synth.set(
            \rate, intervals[symbol>>2] * (2**(symbol&3)) / 3,
            \formant, 2**(head /8 / (head.abs /8 + 1) * 5 + 9),
            \gain, 2**(-0.002*head*head)*0.1
        );
        // (2**(state>>1) * 0.02 * if((state&1)==0){1.5}{1}).wait;
        ((state>>1 + 1) * 0.02 / if((state&1)==0){1.5}{1}).wait;

    };
}.play;
)

~lastsoundbuf.plot
~lastfeatbuf.plot
~laststatsbuf.plot//(separately:true)

~laststatsbuf.numFrames * ~laststatsbuf.numChannels

s.record
s.stopRecording