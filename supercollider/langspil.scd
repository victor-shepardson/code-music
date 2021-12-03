///TODO:
// combine patches
// controller
// recording

(
//MOTU
s.options.numInputBusChannels = 9;
s.options.numOutputBusChannels = 3;

s.options.blockSize = 4;
s.options.sampleRate = 96000;

s.boot;

MIDIIn.connectAll;
)

s.quit

MIDIFunc.trace


(
~room_buses = [7,8];
~pup_buses = [4,5,6]; // MOTU analog 1,2,3
~output_bus = 2;
~rec_channels = 1 + ~room_buses.size + ~pup_buses.size;
// stereo room + 3 pickups + out to tranducer
~record_bus = Bus.audio(s, ~rec_channels);

~monitor_mappings = (~room_buses ++ ~pup_buses ++ [~output_bus]).collect{
    arg bus, idx; bus -> (idx + ~record_bus.index)
};
~monitors = ~monitor_mappings.collect{
    arg evt; Monitor.new.play(evt.key, 1, evt.value)}
)

s.record(bus:~record_bus, numChannels:~rec_channels);


(
~synth = SynthDef(\langspil2, { arg
    shift_hz = 7,//-3e-2,
    low_pass = 5000,
    drive = 1,
    thresh = 1e-1,
    gain = 1,
    comp_exponent = 1;

    var att = 3e-2;
    var rel = 1e-1;

    var pup1 = SoundIn.ar(~pup_buses[0]);
    var pup2 = SoundIn.ar(~pup_buses[1]);
    var pup3 = SoundIn.ar(~pup_buses[2]);

    var pups = [pup1, pup2/6, pup3] * drive;

    var filt = LPF.ar(pups, low_pass);

    var amps = Amplitude.ar(pups, att, rel);

    var onsets = Decay.ar(FluidAmpSlice.ar(pups,
        fastRampUp: 30, fastRampDown: 9600, slowRampUp: 19200,
        slowRampDown: 19200, onThreshold: 15, offThreshold: 3,
        floor: -70, minSliceLength: 960, highPassFreq: 100
    ), 3).pow(0.25);

    var comp = filt / ((amps/thresh).pow(comp_exponent) + thresh) * 3e-2;
    // var comp = filt;

    var shift_up = FreqShift.ar(comp, shift_hz*onsets);
    var shift_down = FreqShift.ar(comp, 0-shift_hz*2.log*onsets);

    var premix = shift_up + shift_down / 2 * onsets;


    var mix = HPF.ar(Mix.ar(premix), 20) * gain;

    /*f0s[0].poll(5, \f1);
    f0s[1].poll(5, \f2);
    f0s[2].poll(5, \f3);

    purity[0].poll(5, \p1);
    purity[1].poll(5, \p2);
    purity[2].poll(5, \p3);

    amps.poll(5, \amp);*/

    onsets.poll(5, \onsets);

    comp.poll(5, \comp);


    Out.ar(~output_bus, mix);
}).play;
)


(
~synth = SynthDef(\langspil, { arg
    shift_hz = 0,//-3e-2,
    shift_ratio = 0.0,//3.3333e-1,
    shift_mix = 0.5,
    center_freqs = #[100, 200, 400],
    pitch_lag = 3,
    low_pass = 1500,
    drive = 1,
    thresh = 1e-2,
    gain = 1,
    comp_exponent = 1;

    var att = 3e-2;
    var rel = 1e-1;

    var pup1 = SoundIn.ar(~pup_buses[0]);
    var pup2 = SoundIn.ar(~pup_buses[1]);
    var pup3 = SoundIn.ar(~pup_buses[2]);

    var pups = [pup1, pup2/4, pup3] * drive;
    // var f0s = Lag.ar(ZeroCrossing.ar(pups).min(1000).max(30).log, 300e-3).exp;
    var f0_raw = Pitch.kr(pups, 200, 30, 3000,
        clar:1, ampThreshold:1e-4, execFreq:200).flop;
    var f0s = Lag.ar(K2A.ar(f0_raw[0].log), pitch_lag).exp;
    // var f0s = f0_raw[0];
    // var f0s = ZeroCrossing.ar(pups);

    var purity = f0_raw[1];

    // var filt = pups;
    // var filt =  LPF.ar(pups, f0s) + BPF.ar(pups, f0s/2);
    var filt = LPF.ar(pups, low_pass);

    var amps = Amplitude.ar(pups, att, rel);

    var onsets = Decay.ar(FluidAmpSlice.ar(pups,
        fastRampUp: 30, fastRampDown: 9600, slowRampUp: 19200,
        slowRampDown: 19200, onThreshold: 10, offThreshold: 5,
        floor: -50, minSliceLength: 4410, highPassFreq: 100
    ), 1);

    var comp = filt / ((amps/thresh).pow(comp_exponent) + thresh) * 3e-2;

    // var shift = FreqShift.ar(comp, -3e-2);
    // var shift = FreqShiftAA.ar(comp, 300-f0s);
    // var shift = FreqShiftAA.ar(comp, 0-f0s*3/4);
    var shift = FreqShiftAA.ar(comp,
        shift_ratio*f0s*(f0s - center_freqs / center_freqs * 10).clip(-1, 1));

    var shift2 = FreqShift.ar(comp, shift_hz);

    var premix = shift * shift_mix + (shift2 * (1-shift_mix));

    var mix = HPF.ar(Mix.ar(premix), 20) * gain * onsets.sqrt;

    /*f0s[0].poll(5, \f1);
    f0s[1].poll(5, \f2);
    f0s[2].poll(5, \f3);

    purity[0].poll(5, \p1);
    purity[1].poll(5, \p2);
    purity[2].poll(5, \p3);

    amps.poll(5, \amp);*/

    onsets.poll(5, \onsets);


    Out.ar(~output_bus, mix);
}).play;
)

// ~synth.set(\low_pass, 1500)

(
//autonomy 0
// no feedback
// reacts to playing
~synth.set(
    \shift_hz, -1,
    \shift_ratio, 0,
    \shift_mix, 0,
    \pitch_lag, 1,
    \drive, 2,
    \gain, 1,
    \thresh, 1e-1,
    \comp_exponent, 2,
    \low_pass, 5000
))

(
//autonomy 1
//transparent feedback
~synth.set(
    \shift_hz, 0,
    \shift_ratio, 0,
    \shift_mix, 0,
    \pitch_lag, 3,
    \drive, 1,
    \gain, 0.7,
    \thresh, 1e-1,
    \comp_exponent, 0.7
)
)

(
//autonomy 2
// plays itself but can be influenced and controlled to a degree
~synth.set(
    \shift_hz, -1e-2,
    \shift_ratio, 1/2,
    \shift_mix, 0.3,
    \pitch_lag, 3,
    \drive, 1,
    \gain, 0.7,
    \thresh, 3e-2,
    \comp_exponent, 1
))

(
//autonomy 3
//when untouched, plays itself
//when strings are muted, becomes uncontrollable
//when strings are plucked, goes dead
~synth.set(
    \shift_hz, 1e-1,
    \shift_ratio, 1/3,
    \pitch_mix, 0.5,
    \pitch_lag, 0.1,
    \drive, 1e1,
    \gain, 1,
    \thresh, 1e-2,
    \comp_exponent, 2
))