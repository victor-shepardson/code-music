include("SuperDirt")

(
s.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
s.options.memSize = 8192 * 64; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 0; // set this to your hardware input channel size, if necessary
// boot the server and start SuperDirt
s.waitForBoot({
	~dirtchannels = 2;
	~dirtorbits = 4;
	//~dirtbusses = all {:Bus.audio(s, ~dirtchannels), i <- (1..~dirtorbits)};
    ~dirtbusses = Array.fill(~dirtorbits, {Bus.audio(s, ~dirtchannels)});

	//start SuperDirt
	d = SuperDirt(~dirtchannels, s);
	//load samples (path containing a wildcard can be passed in)
	d.loadSoundFiles;
	//s.sync; // wait for samples to be read
	//d.start(57120, all {:x.index, x <- ~dirtbusses});
    d.start(57120, ~dirtbusses.collect({|x| x.index}));

	//create a proxyspace
	p = ProxySpace.new;
});
)

(
p.clear;
p.pop;

//create a proxy for each orbit
for(0,~dirtorbits-1,{ |i|
	var id = ['orbit', i].join.asSymbol;
	id.postln;
	p[id].ar(~dirtchannels);
	p[id] = {InBus.ar(~dirtbusses[i], ~dirtchannels)};
});

p.push(s);
~preout.ar(8);
~out.ar(8);
~out.play;
)

(
f = Environment.new;
f[\wiggle] = { |in, amt=0.001, rate=3, rates=#[0.01, 0.1, 1], shape=1, dry=0|
	var waveform = {|r, m| var freq = r*(2**m);
		SinOsc.kr(freq) + LFNoise1.kr(freq*2) / 2;
	},
	wave = 0;
	for (0, rates.size-1, { |i|
		wave = waveform.(rate*rates[i], wave*shape);
	});
	dry*in + DelayC.ar(in, 3*amt, (wave+1)*amt/2+(SampleDur.ir*4))
};

f[\sincextremum] = { |n|
    var q = n+0.5*pi;
    q - (1/q) - (q.pow(-3)*2/3)
};

f[\sinc] = { |phi| var zero = (phi.abs<1e-8); phi.sin+zero/(phi+zero)};


f[\sincosc] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, iphase=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:iphase),
    band_ = band.min(cutoff/freq).max(0).floor+1,
	scale = f[\sincextremum].(band_);
    f[\sinc].(phi*scale+pm)-(0.5pi/scale*fixdc)*mul*EnvGate.new+add
};

f[\sincosci] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor).max(0)+1,
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil),
    osc0 = f[\sinc].(phi*scale0+pm)-(0.5pi/scale0*fixdc),
    osc1 = f[\sinc].(phi*scale1+pm)-(0.5pi/scale1*fixdc);

    m*osc1+(1-m*osc0)*mul*EnvGate.new+add
};

f[\poly] = { |x, s_i, v_f|
    var x_ = x.abs;
    s_i-v_f/2*x_ - (s_i-v_f*3/2)*x_ + s_i*x_ * x.sign
};
f[\sincosci2] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor).max(0)+1,
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil),
    scale = f[\sincextremum].(band_),
    x0 = f[\poly].(phi, scale, scale0),
    x1 = f[\poly].(phi, scale, scale1),
    osc0 = f[\sinc].(x0+pm)-(0.5pi/scale0*fixdc),
    osc1 = f[\sinc].(x1+pm)-(0.5pi/scale1*fixdc);

    m*osc1+(1-m*osc0)*mul*EnvGate.new+add
};

// sincwave synth
// carrier: audio rate sinc w envelopes, overtones
// audio rate sin AM modulator, TODO: interpolating rational interval, modulation indices, envelopes
// TODO: liminal rate sinc AM+meta modulator, fixed freq, overtones, indices, envelopes
SynthDef(\sinc, { |out, fadein=0.001, fadeout=0.005, att=0, dec=0, rel=0, sus=1, curve=0, partials=3, sustain, delta, pan, freq, speed|
    var fr = freq*speed;
    var begin = Impulse.ar(0);
    var gate = Trig.ar(begin, sustain-rel);
    var renv = EnvGen.ar(Env.asr(fadein, 1, fadeout, -3), Trig.ar(begin, sustain-fadeout), doneAction:2);
    var lenv = EnvGen.ar(Env.adsr(att, dec, sus, rel, 1, curve), gate)*0.9999+0.0001; //whyyyy
    var interval = 1/3;
    var cf = interval+1*fr/2;
    var mf = interval-1*fr/2;
    var carrier = f[\sincosci2].(cf, lenv*(partials-1)+1)*lenv;
    var modulator = SinOsc.ar(mf);
    var sound = carrier*modulator;
    OffsetOut.ar(out, DirtPan.ar(sound, d.numChannels, pan, renv))
}).add;
d.soundLibrary.addSynth(
    \sinc, (instrument:\sinc, fadein:0.001, fadeout:0.005, att:0, dec:0, rel:0, legato:1, sustain: {
        (~delta*~legato).max(~att.max(~fadein)+~dec)+~rel.max(~fadeout)
    })
);

)

/*
AM of sins with freq c, m:
c -> c-m, c+m
c > m > 0
desired fundamental f, interval a:
f = c-m
a*f = c+m
a = (f+2m)/f
carrier and modulator set to:
m = (a-1)f/2
c = f+m = (a+1)f/2
what if harmonics of c are present?
c  ->  c-m,  c+m = f, af
2c -> 2c-m, 2c+m = (a+3)/2f, (3a+1)/2f
3c -> 3c-m, 3c+m = (a+2)f, (2a+1)f
4c -> 4c-m, 4c+m = (3a+5)/2f, (5a+3)/2f
limiting case a=1: 1, 1, 2, 2, 3, 3, 4, 4 as expected
case a=3/2: 1, 3/2, 9/4, 11/4, 7/4, 4, 7/2, 21/4
in 4ths, sorted: 4, 6, 7, 9, 11, 14, 16, 21 (sparse harmonics of f/4)
case a=2: 1, 2, 5/2, 7/2, 4, 5, 11/2, 13/2
in 2ves: 2, 4, 5, 7, 8, 10, 11, 13 (dense harmonics of f/2)
case a=3: 1, 3, 3, 5, 5, 7, 7, 9 (odd harmonics, unsure what phase does though)
case a=4: 1, 4, 7/2, 13/2, 6, 7, 17/2, 23/2
in 2ves: 2, 7, 8, 12, 13, 14, 17, 23 (sparse harmonics of f/2)
the rule for the "phantom fundamental" is: denominator of modulator, down an octave if denominator or numerator is even.
*/

(
~fx0 = {f[\wiggle].(~orbit0, rate:3, amt:0.001)};
~fx1 = {f[\wiggle].(~orbit1, rate:2, amt:0.003, dry:0.5)};
~fx2 = {f[\wiggle].(~orbit2, rate:5, amt:0.002, dry:0.2)};
~fx3 = {f[\wiggle].(~orbit2, rate:5, amt:0.002, dry:0.2)};


~amb0 = {
	GVerb.ar(
        Mix.new(~orbit0.ar),
        roomsize:50, revtime:1.5, damping:0.9, spread:5,
        earlyreflevel: 0.0,
        drylevel:0, mul:0.03
)};

~amb1 = {
	GVerb.ar(
		HPF.ar(Mix.new(~orbit1.ar), freq:300),
		roomsize:100, revtime:5, damping:0.7, spread:1,
		earlyreflevel: 0.0,
		drylevel:0, mul:0.05
)};

~amb2 = {
    f[\wiggle].(
        GVerb.ar(
            HPF.ar(Mix.new(~orbit2.ar), freq:60),
            roomsize:40, revtime:2.5, damping:0.5, spread:10,
            earlyreflevel: 0.4,
            drylevel:0, mul:0.08
        ), dry:0.3, rate:1/3, amt:0.008
)};

~preout = [~fx0+~amb0, ~fx1+~amb1, ~fx2+~amb2, ~fx3+~amb3];

~out = {Limiter.ar(0.7*~preout.ar)};
)

s.quit

3/2
4/3
5/3
5/4
7/4
6/5
7/5
8/5
9/5
7/6
11/6
8/7
9/7
10/7
11/7
12/7
13/7
9/8
11/8
13/8
15/8
10/9
11/9
13/9
14/9
15/9
16/9
2**(9/12)
