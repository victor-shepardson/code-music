(
s.options.memSize = 8192 * 64;
s.boot
)

s.quit

// TODO:
//    recording interface
//    pitch/rhythm features
//    cmd .
//    OO refactor
//    way to have silences? state/symbol gain?
//    performance; maybe turn off expander; stop distant seeds
//       4 band 300-3000 ? 200 - 4000 ?

//    intervals:
//       FluidBufChroma; FluidBufPitch for weights
//       weighted mean chroma / weighted pitch clusters?
//       enumerate ratios in order of prominence

//    synth ideas:
//      cepstral decomp / spectral eveloping - vary timbre and pitch-speed separately
//      narrower register for pitched sounds, wider for percussive, no speed change for noise?
//      segment sound, and sync TM delay with sound duration (i.e. segment duration / rate)
//        more elegant than getting some rhythmic features and mapping to delays
//        lang/synth sync could be hard. would need to switch from looper to sampler-style synth?
//    FluidBufHPSS;
//    FluidBuf*Slice on percussive part;
//    GrainBuf to trigger percussive segments as the looper reaches them

//    visualizer (for finding loops especially?)

//    temporal features -> program: fill instructions in the order first visited
//    better discretization:
//      clustering? would want the clusters to be general, not specific to each utterance
//        (at least deterministic)
//      discrete neural embedding (wav2vec?) could be ideal
//      need to A. adapt to seed length and B. adapt to instruction width
//      A: could loop with an offset
//         (i.e. shorter seed has smaller hop size, but ordered so sound prefix = program prefix)
//      B: could increase width using N-grams;
//         decrease width by truncating bits (making some classes the same)

(
// SOUND SEED GARDEN
var log_n_bands = 3;
var n_bands = 1<<log_n_bands;
~send_bus = Bus.audio(s, 2);  // raw, multi-band, mixdown
~sum_bus = Bus.audio(s, n_bands*2);  // raw, multi-band, mixdown
~exp_bus = Bus.audio(s, n_bands*2);  // expanded, multi-band, mixdown
~max_bus = Bus.audio(s, n_bands);  // rms, multi-band, reduce-max

~max_frames = s.sampleRate * 10;
~n_channels = 1;
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

~crossover = {
    arg input = PinkNoise.ar,
    lo = 100,
    hi = 8000,
    n = 3;

    var step = {arg sig, freq;
        var lp = LPF.ar(LPF.ar(sig,freq),freq), hp = HPF.ar(HPF.ar(sig,freq),freq);
        // var lp = LPF.ar(sig,freq,mul:-1), hp = HPF.ar(sig,freq);
        [lp, hp]
    };

    var signals = [input];
    var freqs = [(lo.log + hi.log / 2).exp];
    var base = hi/lo ** ( 1/ (n-1*n));
    n.do{
        arg level;
        var spread = n - 1 - level;
        spread;
        signals = signals.collect{arg sig, idx; step.(sig, freqs[idx])}.flatten;
        freqs = freqs.collect{arg freq; [base**(0-spread)*freq, base**spread*freq]}.flatten
    };
    // Amplitude.ar(input,0.05,0.05).poll(5, \input);
    // Amplitude.ar(signals.sum,0.05,0.05).poll(5, \sum__);
    // [signals.sum, input]
    signals
};
// {~crossover.()}.play

~pan = {
    arg signal, pan=0;
    var path_dist = 0.3;
    var max_dist = 10;
    var head_radius = 0.1;
    var sound_speed = 300;
    var min_time = 0;//SampleDur.ir * 4.0;
    var disps = [0-head_radius, head_radius]-pan;
    var dists = (path_dist*path_dist + (disps*disps)).sqrt;
    var gains = 1/(1+dists); // inverse square instead?
    var signals = [signal, signal]*0.71;
    var max_time = max_dist/sound_speed+min_time;
    signals = BLowShelf.ar(signals, 1200, db:gains.log10*20);
    DelayC.ar(signals, max_time,
        (dists/sound_speed+min_time).min(max_time),
        mul:gains);
};

// one synth runs for each input, reduces to buses
~reduce = { arg input, sharpness=3, rms_cutoff=100,  attack=3e-3, decay=1e-1, distance=0;
    var delay = 8/SampleDur.ir + attack;
    var edist = 2**distance;
    var distanced = LPF.ar(HPF.ar(input,
        (20*edist).min(20000)), (20000/edist).max(40))/edist;
    var to_send = input*(1+distance);
    var bands_l = ~crossover.(distanced[0], n:log_n_bands);
    var bands_r = ~crossover.(distanced[1], n:log_n_bands);
    var bands = bands_l+bands_r;
    var envs = Amplitude.ar(BLowPass4.ar(bands*bands, rms_cutoff).sqrt, attack, decay);
    var delayed = DelayN.ar(bands_l++bands_r, 0.1, delay);
    var exp_envs = (envs*sharpness).exp;
    var expanded = delayed * exp_envs;
    Out.ar(~send_bus, to_send); // singleband stereo
    Out.ar(~sum_bus, delayed); // multiband stereo
    Out.ar(~exp_bus, expanded); // multiband stereo
    Out.ar(~max_bus, (envs-In.ar(~max_bus)).max(0)); //multiband mono
};

// another synth combines the buses into final mixdown
SynthDef(\mixdown, { arg outbus=0,
    rms_cutoff=100, max_thresh=0.2, min_thresh=0.01,
    ratio=0.125, epsilon=1e-5, attack=3e-3, decay=1e-1;
    var delay = 8/SampleDur.ir + attack;
    var bands_raw_l = In.ar(~sum_bus, n_bands);
    var bands_raw_r = In.ar(~sum_bus.index+n_bands, n_bands);
    var bands_raw = bands_raw_l + bands_raw_r;
    var bands_exp_l = In.ar(~exp_bus, n_bands);
    var bands_exp_r = In.ar(~exp_bus.index+n_bands, n_bands);
    var bands_exp  = bands_exp_l + bands_exp_r;
    // crackling with large number of seeds: might be fixed by filtering env_max?
    var env_max = BLowPass4.ar(In.ar(~max_bus, n_bands), rms_cutoff);
    var env_raw = Amplitude.ar(BLowPass4.ar(bands_raw*bands_raw, rms_cutoff).sqrt, 0.001, 0.1);
    var env_exp = Amplitude.ar(BLowPass4.ar(bands_exp*bands_exp, rms_cutoff).sqrt, 0.001, 0.1);
    var thresh = env_max.min(max_thresh).max(min_thresh);
    var env = (env_raw - thresh).max(0) * ratio + env_raw.min(thresh); //mono
    var bands_exp_delayed_l = DelayN.ar(bands_exp_l, 0.1, delay);
    var bands_exp_delayed_r = DelayN.ar(bands_exp_r, 0.1, delay);
    var gain = env / (env_exp+epsilon);
    var bands_out_l = bands_exp_delayed_l * gain;
    var bands_out_r = bands_exp_delayed_r * gain;

    var sig_out = [bands_out_l.sum, bands_out_r.sum]; // over bands
    Out.ar(outbus, sig_out);
}).add;

SynthDef(\soundseed, { arg soundbuf, databuf;
    var frames = BufRd.ar(1, databuf, DC.ar(0), interpolation:1);
    var phase = Phasor.ar(0, (frames>0)*\rate.kr(0, 0.02)*BufRateScale.kr(soundbuf), 0, frames);
    var sound = BufRd.ar(1, soundbuf, phase);
    ~reduce.(~pan.(
        sound * \gain.kr(0.5, 0.3),
        // Formlet.ar(
        // sound,
        // \formant.kr(512, 0.1),
        // 0.001, 0.005,
        // mul: \gain.kr(0.1, 0.3)),
        \center.kr(0, 0.03)
    ))
}).add;

~mixdown = Synth.tail(s, \mixdown, []);
~ambience = {MiVerb.ar(In.ar(~send_bus, 2),
    mul:0.05, drywet:1, time:0.1)
}.play(addAction:'addToTail');
)

(
// SOUND SEED
var soundbuf = ~lastsoundbuf = Buffer.alloc(s, ~max_frames, ~n_channels);
var databuf = Buffer.alloc(s, 1);
var featbuf = ~lastfeatbuf = Buffer.new;
var statsbuf = ~laststatsbuf = Buffer.new;
var state_bits = 5;
var symbol_bits = 4;
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
var visits = Dictionary.new;
var program;

var mel_bands = 64;
var n_moments = 4; // max 4 (7)
var n_derivs = 2; //  max 2

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
                        program[pidx] = quantize.(stat.abs, 256, floor:0, range:60).bitXor(0xf0);//.postln;
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

var synth = Synth(\soundseed, [
    soundbuf:soundbuf, databuf:databuf//, center:0.gaussian/2, distance:5.0.linrand
]);
var intervals = [1, 3/2, 5/4, 2, 4/3, 5/3, 9/8, 15/8];

~node_cond[node_id] = CondVar.new;

Routine {
    //  record for 1 second. TODO: instead wait for a control
    1.wait;
    rec.set(\stop, 1);
    ~node_cond[node_id].wait;
    sound_length = ~node_data[node_id];
    rec.free;

    \stopped.postln;

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

    // 1.wait;

    // s.makeBundle(1, {rec.free});

    loop {
        var vis, vis_key;
        var symbol = tape[head] ? 0;
        var new_state, new_symbol, move_idx, move;
        // "step: % \t head: % \t state: % \t symbol: %".format(step, head, state, symbol).postln;
        # new_state, new_symbol, move_idx = get_instruction.(state, symbol);

        // tricks to get more interesting machines:
        // move = if(symbol==0){0-head.sign}{movements[move_idx]}; //symbol zero move -> center
        // new_symbol = if(new_symbol==0){1}{new_symbol}; // 0 is never written
        move = movements[move_idx];

        if (new_symbol!=0) {tape[head] = new_symbol};
        head = head + move;

        vis_key = [head, state, symbol];
        vis = (visits[vis_key] ? 0) + 1;
        visits[vis_key] = vis;

        state = new_state;
        step = step + 1;
        synth.set(
            \rate, intervals[symbol>>1] * (2**(symbol&1)) / 2,
            \center, head/100,
            \distance, head.abs/30 + (vis/3),
            // \formant, 2**(head /8 / (head.abs /8 + 1) * 5 + 9),
            // \gain, 2**(-0.002*head*head)*0.1 * (vis** -0.5)
            // \gain, 0.1 * ((head.abs+1) ** -0.25) / vis;//* (vis ** -0.75)
            // \gain, 0.5 / vis//* (vis ** -0.75)

        );
        // (2**(state>>1) * 0.02 * if((state&1)==0){1.5}{1}).wait;
        ((state>>1 + 1) * 0.03 / if((state&1)==0){1.5}{1}).wait;
    };
}.play;
)

~lastsoundbuf.plot
~lastfeatbuf.plot
~laststatsbuf.plot//(separately:true)

~laststatsbuf.numFrames * ~laststatsbuf.numChannels

s.record
s.stopRecording