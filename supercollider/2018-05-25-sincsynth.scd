(
s.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
s.options.memSize = 8192 * 64; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 0; // set this to your hardware input channel size, if necessary
// boot the server and start SuperDirt
s.waitForBoot({
	~dirtchannels = 2;
	~dirtorbits = 3;
    ~dirtbusses = Array.fill(~dirtorbits, {Bus.audio(s, ~dirtchannels)});

	//start SuperDirt
	d = SuperDirt(~dirtchannels, s);
	//load samples (path containing a wildcard can be passed in)
	d.loadSoundFiles;
	//s.sync; // wait for samples to be read
    d.start(57120, ~dirtbusses.collect({ |x| x.index}));

	//create a proxyspace
	p = ProxySpace.new;
});
)

(
//create a proxy for each orbit
for(0,~dirtorbits-1,{|i|
	var id = ['orbit', i].join.asSymbol;
	id.postln;
	p[id].ar(~dirtchannels);
	p[id] = {InBus.ar(~dirtbusses[i], ~dirtchannels)};
});

p.push(s);
~preout.ar(2);
~out.ar(2);
~out.play;
f = Environment.new;
)

(

f[\sincextremum] = { |n|
    var q = n+0.5*pi;
    q - (1/q) - (q**(-3)*2/3)
};

f[\sinc] = { |phi| (phi.abs>1e-7).if(phi.sin/phi, 1)};

f[\sincosc] = { |freq, band=1, mul=1, add=0, cutoff=24000|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min(cutoff/freq).max(1).floor,
	scale = f[\sincextremum].(band_);
    f[\sinc].(phi*scale)*mul*EnvGate.new+add
};

f[\sincosci] = { |freq, band=1, mul=1, add=0, cutoff=24000, pm=0|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor).max(1),
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil);
    m*f[\sinc].(phi*scale1+pm)+(1-m*f[\sinc].(phi*scale0+pm))*mul*EnvGate.new+add
};

f[\lancosc] = {
    |freq, band=1, mul=1, add=0, cutoff=24000|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min(cutoff/freq).max(1),
	scale = pi*band;//f[\sincextremum].(band_);
    f[\sinc].(phi*scale)*f[\sinc].(phi*pi)*mul*EnvGate.new+add
};

// "sustain" is the duration sent by tidal. it should include attack and decay but not release
SynthDef(\sinc, { |out, att=0, dec=0, rel=0, sus=1, curve=0, sustain=1, partials=8, pan, freq|
    var fadein = 0.001, fadeout = 0.005;
    var begin = Impulse.ar(0);
    var gate = Trig.ar(begin, sustain-rel.max(fadeout));
    var renv = EnvGen.ar(Env.asr(fadein, 1, fadeout, 1, -3), Trig.ar(begin, sustain-fadeout), doneAction:2);
    var lenv = EnvGen.ar(Env.adsr(att, dec, sus, rel, 1, curve), gate)*0.9999+0.0001; //whyyyy
    var sound = (f[\sincosci].(freq*lenv, lenv*partials)*lenv*0.5pi).sin;
    // var sound = f[\sincosci].(freq*lenv, lenv*partials, pm:mod*1pi)*lenv;
    // var sound = f[\sincosci].(freq*lenv, lenv*partials)*lenv;
    // var sound = f[\lancosc].(freq, partials);
    // var sound = f[\lancosc].(freq, partials);
    // var sound = f[\sincosci].(freq*lenv, partials);
    // sound = LeakDC.ar(sound, 0.99);
    // var sound = f[\sincosci].(freq, partials);
	OffsetOut.ar(out, DirtPan.ar(sound, d.numChannels, pan, renv))
}).add;

// "sustain" is the duration sent by tidal. it should include attack and decay but not release
SynthDef(\sincfm, { |out, att=0, dec=0, rel=0, sus=1, curve=0, midx=2, mratio=0.03125pi, mpartials=8, partials=8, sustain=1, pan, freq|
    var fadein = 0.001, fadeout = 0.005;
    var begin = Impulse.ar(0);
    var gate = Trig.ar(begin, sustain-rel.max(fadeout));
    var renv = EnvGen.ar(Env.asr(fadein, 1, fadeout, 1, -3), Trig.ar(begin, sustain-fadeout), doneAction:2);
    var lenv = EnvGen.ar(Env.adsr(att, dec, sus, rel, 1, curve), gate)*0.9999+0.0001; //whyyyy
    var mod = f[\sincosci].(freq*lenv*mratio, lenv*mpartials);
    var sound = (f[\sincosci].(freq*(2**(mod*midx*lenv)), lenv*partials)*lenv*0.5pi).sin;
	OffsetOut.ar(out, DirtPan.ar(sound, d.numChannels, pan, renv))
}).add;
)

/*SynthDef(\adsrsynth, { |out, att=0, dec=0, sus=0.5, rel=0, curve=0, sustain=1, pan, freq|
    var fadein = 0.001, fadeout = 0.003;
    var begin = Impulse.ar(0);
    var cut_env = EnvGen.ar(
        Env.asr(fadein, 1, fadeout, 1, -3),
        Trig.ar(begin, sustain-fadeout), doneAction:2);
    var sound_env = EnvGen.ar(
        Env.adsr(att, dec, sus, rel, 1, curve),
        Trig.ar(begin, sustain-rel));
    var sound = ...;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, cut_env))
}).add;*/

(
~preout = ~orbit0 + ~orbit1 + ~orbit2;
//~preout = ~orbit0 + ~orbit1 + ~orbit2;// + ~amb0 + ~amb1 + ~amb2;
~out = {Limiter.ar(0.5*~preout.ar)};
)

s.record("~/record/2018-05-25-sketch.wav", 0);
s.stopRecording;

s.quit