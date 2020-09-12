include("SuperDirt")

(
n = NetAddr.new("127.0.0.1", 6010);

s.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
s.options.memSize = 8192 * 64; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 4; // set this to your hardware input channel size, if necessary
// boot the server and start SuperDirt
s.waitForBoot({
	~dirtchannels = 2;
	~dirtorbits = 3;
	//~dirtbusses = all {:Bus.audio(s, ~dirtchannels), i <- (1..~dirtorbits)};
    ~dirtbusses = Array.fill(~dirtorbits, {Bus.audio(s, ~dirtchannels)});

	//start SuperDirt
	d = SuperDirt(~dirtchannels, s);
	//load samples (path containing a wildcard can be passed in)
    d.loadSoundFiles;
	//s.sync; // wait for samples to be read
	//d.start(57120, all {:x.index, x <- ~dirtbusses});
    d.start(57120, ~dirtbusses.collect({ |x| x.index }));

	//create a proxyspace
	p = ProxySpace.new;
});
)

d.loadSoundFiles("~/Music/sample/dirt/*");


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
~preout.ar(2);
~out.ar(2);
~out.play;

~in = {SoundIn.ar([2,3])};
~ml = {MFCC.kr(FFT(LocalBuf(1024), ~in.ar[0]))};
~mr = {MFCC.kr(FFT(LocalBuf(1024), ~in.ar[1]))};

r = {
    inf.do {
        ~ml.bus.getn(13, { |val| val.do({ |v, i| n.sendMsg('/ctrl', ['ml_',i].join, v) }) });
        ~mr.bus.getn(13, { |val| val.do({ |v, i| n.sendMsg('/ctrl', ['mr_',i].join, v) }) });
        0.04.wait; // 25 frames per second
    }
}.fork;
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
// audio rate sin AM modulator, interpolating rational interval, modulation indices, envelopes
// liminal rate sinc AM+meta modulator, fixed freq, overtones, indices, envelopes
SynthDef(\sinc, { |out, fadein=0.001, fadeout=0.005, att=0, dec=0, rel=0, sus=1, curve=0, partials=8, sustain, delta, pan, freq|
    var begin = Impulse.ar(0);
    var gate = Trig.ar(begin, sustain-rel);
    var renv = EnvGen.ar(Env.asr(fadein, 1, fadeout, -3), Trig.ar(begin, sustain-fadeout), doneAction:2);
    var lenv = EnvGen.ar(Env.adsr(att, dec, sus, rel, 1, curve), gate)*0.9999+0.0001; //whyyyy
    var carrier = f[\sincosci2].(freq, lenv*(partials-1)+1);
    var modulator = SinOsc.ar(freq*2.2);
    var sound = carrier*modulator;
    OffsetOut.ar(out, DirtPan.ar(sound, d.numChannels, pan, renv))
}).add;
d.soundLibrary.addSynth(
    \sinc, (instrument:\sinc, fadein:0.001, fadeout:0.005, att:0, dec:0, rel:0, legato:1, sustain: {
        (~delta*~legato).max(~att.max(~fadein)+~dec)+~rel.max(~fadeout)
    })
);

SynthDef(\inzf, { |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, bal=0.5, pan, accelerate, offset|
	var env, sound, rate, phase, f0;
    // phase = Line.ar(begin, end, sustain);
	rate = (begin + 1) * (speed + Sweep.kr(1, accelerate)) * freq;
	sound = SoundIn.ar([2, 3]); // stereo in
    f0 = ZeroCrossing.ar(sound);
	sound = FreqShift.ar(sound, rate-f0);
    sound = sound[0] * (bal-1).sqrt + (sound[1] * bal.sqrt);
	OffsetOut.ar(out,
		DirtPan.ar(sound, ~dirt.numChannels, pan)
	)
}).add;
/*d.soundLibrary.addSynth(
    \inzf, (instrument:\inzf, fadein:0.001, fadeout:0.005, att:0, dec:0, rel:0, legato:1, sustain: {
        (~delta*~legato).max(~att.max(~fadein)+~dec)+~rel.max(~fadeout)
    })
);*/


)

(
f[\sinccos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    sinc = f[\sinc].(ratio*phi*pi),
    cos_env = (pi*phi).cos +1 /2;
    sinc * cos_env
};

f[\coscos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    cos_wave = (ratio*phi*pi).cos,
    cos_env = (pi*phi).cos +1 /2;
    cos_wave * cos_env
};

f[\sinsincos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    fold_wave = ((phi*pi).sin*ratio*pi).sin,
    cos_env = (pi*phi).cos +1 /2;
    fold_wave * cos_env
};

f[\sinsigcos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    squash_wave = ((phi*pi).sin*(ratio**2)/2).distort,
    cos_env = (pi*phi).cos +1 /2;
    squash_wave * cos_env
};

f[\sinsinsigcos] = {
    arg freq, ratio, ratio2;
    var phi = LFSaw.ar(freq, iphase:0),
    fold_wave = ((phi*pi).sin*ratio*pi).sin,
    squash_wave = (fold_wave*(ratio2**2)).distort,
    cos_env = (pi*phi).cos +1 /2;
    squash_wave * cos_env
};

f[\stretch] = {
    arg freq, ratio, osc ...oscargs;
    FreqShift.ar(osc.(freq*ratio, *oscargs), 0-(ratio -1 *freq))
};

t.free;

t = {f[\sinccos].(110,1)}.play

// t = {f[\sinccos].(54.5,SinOsc.kr(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54, (5/3), f[\sinccos], SinOsc.ar(27/3) +1 /2 **2 * 16 +1)}.play;

// t = {f[\stretch].(54, (1), f[\sinccos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54, (1), f[\coscos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54, (1), f[\sinsincos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54*2, (1), f[\sinsigcos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

/*t = {Splay.ar([
f[\stretch].(54*2, (3/4), f[\sinsinsigcos],
    SinOsc.ar(1/32) +1 /2 **2 * 4 + 0.25,
    SinOsc.ar(1/11) +1 /2 **2 * 1 + 0.5
),
f[\stretch].(54*4, (1/4), f[\sinsinsigcos],
    SinOsc.ar(1/45) +1 /2 **2 * 2 + 0.25,
    SinOsc.ar(1/7) +1 /2 **2 * 1 + 0.5
),
f[\stretch].(54*3, (2/4), f[\sinsinsigcos],
    SinOsc.ar(1/65) +1 /2 **2 * 3 + 0.25,
    SinOsc.ar(1/13) +1 /2 **2 * 1 + 0.5
)
])}.play;*/

)


(
~preout = ~orbit0 + ~orbit1 + ~orbit2 + ~amb0 + ~amb1 + ~amb2;

~fx0 = {f[\wiggle].(~orbit0, rate:3, amt:0.0003)};
~fx1 = {f[\wiggle].(~orbit1, rate:2, amt:0.003, dry:0.5)};
~fx2 = {f[\wiggle].(~orbit2, rate:5, amt:0.001, dry:0.2)};

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
        ), dry:0.3, rate:1/3, amt:0.004
)};

~preout = ~fx0 + ~fx1 + ~fx2 + ~amb0 + ~amb1 + ~amb2;
// ~preout = ~orbit0 + ~orbit1 + ~orbit2;
~out = {Limiter.ar(0.7*~preout.ar)};
)

thisProcess.platform.recordingsDir
s.record
s.stopRecording

s.quit