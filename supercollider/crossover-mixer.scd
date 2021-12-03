(
s.options.memSize = 8192 * 64;
s.boot
)

//crossover tree, 2**n bands, log spaced filters from lo to hi
// problem?: at n>3, there are 'inversions', ex:
//    LHH is a lower band than HLL, but has heavier HF tail
//    ex: (<8,>2,>4) vs (>8,<32,<16)
// ^ not apparently a big issue; seem to be phase problems with n > 2 though
//   sensitive to band locations, but not saw wave input pitch
(
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
        freqs = freqs.postln.collect{arg freq; [base**(0-spread)*freq, base**spread*freq]}.flatten
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
    var sound_speed = 100;
    var min_time =  0;//SampleDur.ir * 4.0;
    var disps = [0-head_radius, head_radius]-pan;
    var dists = (path_dist*path_dist + (disps*disps)).sqrt;
    var gains = 1/(1+dists);
    var signals = [signal, signal]*0.71;
    signals = BLowShelf.ar(signals, 1200, db:gains.log10*20);
    DelayN.ar(signals, max_dist/sound_speed+min_time,
        dists/sound_speed+min_time,
        mul:gains);
};
)

// ====== //
// STEREO //
// ====== //

(
var log_n_bands = 3;
var n_bands = 1<<log_n_bands;

var send_bus =  ~send_bus = Bus.audio(s, 2);  // raw, multi-band, mixdown
var sum_bus = Bus.audio(s, n_bands*2);  // raw, multi-band, mixdown
var exp_bus = Bus.audio(s, n_bands*2);  // expanded, multi-band, mixdown
var max_bus = Bus.audio(s, n_bands);  // rms, multi-band, reduce-max

~test_bus !? {~test_bus.free};
~test_bus = Bus.audio(s, 7*2);
~distances = [1, 2, 3, 0, 1, 2, 3];
SynthDef(\test_input, {arg outbus;
    Out.ar(outbus, [
        // ~pan.(Dust2.ar(10)*8, -1),
        ~pan.(LagUD.ar(Impulse.ar(5), 0.00, 0.4)*SinOsc.ar(200), -1),
        ~pan.(LagUD.ar(Impulse.ar(0.3), 0.00, 4)*WhiteNoise.ar*0.5, -0.5),
        ~pan.(LagUD.ar(Impulse.ar(0.5), 0.00, 8)*PinkNoise.ar, -0.1),
        ~pan.(LagUD.ar(Impulse.ar(2), 0.00, 0.5)*SinOsc.ar(500), 0),
        ~pan.(LagUD.ar(Impulse.ar(1.5), 0.00, 1)*Saw.ar(100), 0.1),
        ~pan.(LagUD.ar(Impulse.ar(0.8), 0.00, 2)*Blip.ar(1000), 0.5),
        ~pan.(LagUD.ar(Impulse.ar(2.7), 0.00, 0.5)*Blip.ar(700, 32)*2, 1),
].flatten*0.5)}
).add;

// one synth runs for each input, reduces to buses
SynthDef(\reduce, { arg inbus, sharpness=3, rms_cutoff=100,  attack=3e-3, decay=1e-1, distance=0;
    var delay = 8/SampleDur.ir + attack;
    var input = In.ar(inbus, 2);
    var distanced = input*(2**(0-distance));
    var to_send = input*(1+distance);
    var bands_l = ~crossover.(distanced[0], n:log_n_bands);
    var bands_r = ~crossover.(distanced[1], n:log_n_bands);
    var bands = bands_l+bands_r;
    var envs = Amplitude.ar(BLowPass4.ar(bands*bands, rms_cutoff).sqrt, attack, decay);
    var delayed = DelayN.ar(bands_l++bands_r, 0.1, delay);
    var exp_envs = (envs*sharpness).exp;
    var expanded = delayed * exp_envs;
    Out.ar(send_bus, to_send); // singleband stereo
    Out.ar(sum_bus, delayed); // multiband stereo
    Out.ar(exp_bus, expanded); // multiband stereo
    Out.ar(max_bus, (envs-In.ar(max_bus)).max(0)); //multiband mono
}).add;

// another synth combines the buses into final mixdown
SynthDef(\mixdown, { arg outbus=0, rms_cutoff=100, max_thresh=0.2, min_thresh=0.01, ratio=0.125, epsilon=1e-5, attack=3e-3, decay=1e-1;
    var delay = 8/SampleDur.ir + attack;
    var bands_raw_l = In.ar(sum_bus, n_bands);
    var bands_raw_r = In.ar(sum_bus.index+n_bands, n_bands);
    var bands_raw = bands_raw_l + bands_raw_r;
    var bands_exp_l = In.ar(exp_bus, n_bands);
    var bands_exp_r = In.ar(exp_bus.index+n_bands, n_bands);
    var bands_exp  = bands_exp_l + bands_exp_r;
    var env_max = In.ar(max_bus, n_bands);
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
max_bus.scope;
)


(
Synth.tail(s, \test_input, [\outbus, ~test_bus]);
~distances.do{arg dist, idx; Synth.tail(s, \reduce, [
    \inbus, 2*idx+~test_bus.index, \distance, dist
])};
Synth.tail(s, \mixdown, []);
{MiVerb.ar(In.ar(~send_bus, 2), mul:0.05, drywet:1, time:0.1)}.play(addAction:'addToTail');
)
