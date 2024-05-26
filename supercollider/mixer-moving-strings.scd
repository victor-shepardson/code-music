// TODO: get small shift working, insert or otherwise























//
// VICTOR SHEPARDSON
//
// NO-INPUT MIXING
//





(
//kmix
s.options.numInputBusChannels = 8;
s.options.numOutputBusChannels = 8;

s.options.blockSize = 64;
s.options.sampleRate = 96000;

s.boot;
)

s.quit


(
~main_buses = [2, 3];
// ~inserts = [(4->2)];
~output_buses = [0, 1];
// ~aux_buses = [2, 3];
)

// reuse + salvage
// sensitive
// left/right tones, pan, cut
// aux clicks
// headphone, rec
// clicks demo w headphone pan, rec
// 2tr button
// dialogue
// shifter

(
~synth = SynthDef(\mixer, {
    // var ins = SoundIn.ar(~main_buses)
    var in_left = SoundIn.ar(~main_buses[0]);
    var in_right = SoundIn.ar(~main_buses[1]);
    var ins = [in_left, in_right];

    var f0_raw = ZeroCrossing.ar(LPF.ar(ins, 1000));
    var f0s = Lag.ar(f0_raw[0].log, \pitch_lag.kr(5e-4)).exp;

    var shifted = FreqShiftAA.ar(ins,
        \target_freq.kr([180, 240], 1) - f0s);

    // var limited = Limiter.ar(ins, 0.2, );
    var limited = Limiter.ar(shifted, 0.2);

    f0s.poll(5, \f0);

    ~output_buses.collect{arg bus, idx;
        Out.ar(bus, limited[idx])};
}).play;
)

~synth.set(\target_freq, 300)
~synth2.set(\target_freq, 200)

s.quit
