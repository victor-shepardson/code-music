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
for(0, ~dirtorbits-1, { |i|
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

f[\sinc] = { |phi| var zero = (phi.abs<1e-8); phi.sin+zero/(phi+zero)};

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

SynthDef(\sinc, { |out, fadein=0.001, fadeout=0.005, att=0, dec=0, rel=0, sus=1, curve=0, partials=8, sustain, delta, pan, freq|
    var begin = Impulse.ar(0);
    var gate = Trig.ar(begin, sustain-rel);
    var renv = EnvGen.ar(Env.asr(fadein, 1, fadeout, -3), Trig.ar(begin, sustain-fadeout), doneAction:2);
    var lenv = EnvGen.ar(Env.adsr(att, dec, sus, rel, 1, curve), gate)*0.9999+0.0001; //whyyyy
    var sound = (f[\sincosci].(freq, lenv*(partials-1)+1)*lenv*0.5pi).sin;
    OffsetOut.ar(out, DirtPan.ar(sound, d.numChannels, pan, renv))
}).add;
d.soundLibrary.addSynth(
    \sinc, (instrument:\sinc, fadein:0.001, fadeout:0.005, att:0, dec:0, rel:0, legato:1, sustain: {
        (~delta*~legato).max(~att.max(~fadein)+~dec)+~rel.max(~fadeout)
    })
);

SynthDef(\sincfm, { |out, fadein=0.001, fadeout=0.005, att=0, dec=0, rel=0, sus=1, curve=0, midx=2, mratio=0.03125pi, mpartials=8, partials=8, sustain, delta, pan, freq|
    var begin = Impulse.ar(0);
    var gate = Trig.ar(begin, sustain-rel);
    var renv = EnvGen.ar(Env.asr(fadein, 1, fadeout, -3), Trig.ar(begin, sustain-fadeout), doneAction:2);
    var lenv = EnvGen.ar(Env.adsr(att, dec, sus, rel, 1, curve), gate)*0.9999+0.0001; //whyyyy
    var mod = f[\sincosci].(freq*lenv*mratio, lenv*(mpartials-1)+1);
    var sound = (f[\sincosci].(freq*(2**(mod*midx*lenv)), lenv*(partials-1)+1)*lenv*0.5pi).sin;
    OffsetOut.ar(out, DirtPan.ar(sound, d.numChannels, pan, renv))
}).add;
d.soundLibrary.addSynth(
    \sincfm, (instrument:\sincfm, fadein:0.001, fadeout:0.005, att:0, dec:0, rel:0, legato:1, sustain: {
        (~delta*~legato).max(~att.max(~fadein)+~dec)+~rel.max(~fadeout)
    })
);

// option 1: use generic envelopes and set modulation for each parameter/envelope pair
// one adsr envelope + one or more asr
//   param = value*scale(pow(env[i], curve), lo, hi)
// option 2: use an envelope for each parameter
//   sus = param, att=0, dec=0, rel=inf?
//   env timing:
//     att/dec: either match, unique att without dec (asr, includes case of none when att=0)
//       att = negative to scale master envelope, positive to set.
//     rel: either match or none (rel=inf?)
//       negative to scale master envelope, postive to set, 0 to skip
//   env values:
//     curve for each parameter
//     start, (peak), sus, end values
//   separate att from dec/sus and rel: /``` * `^-- * ```\
//      this allows asr-like behavior when dec not longer than att, but also adsr-like behavior when it is
//   fix sustain level at 1, have a peak value with default 1
//        att from 0 to 1 from t=0 to att
//        dec from peak to sus from t=0 to dec
//        rel from 1 to 0 from t=end to end+rel
//   envelope with start/end=0, peak=2, and sus=1. then curve+scale to given values (i.e. values determine curve)
//     (e+p-2s)/2 * x^2 + (-3e-p+4s)/2 * x + e
SynthDef(\sinc2, { |
    out, fadein=0.001, fadeout=0.005,
    att=0, dec=0, rel=0, pk=1, sus=1, end=0,
    pk_ovt=31, sus_ovt=7, end_ovt=0,
    pk_oct=0, sus_oct=0, end_oct=0,
    sustain, delta, pan, freq
    |
    var begin = Impulse.ar(0);
    var renv = EnvGen.ar(Env.asr(fadein, 1, fadeout, -3), Trig.ar(begin, sustain-fadeout), doneAction:2);
    var lenv = (
        EnvGen.ar(Env.asr(att, 1, 0, 0), Trig.ar(begin, sustain), doneAction:2)
        * (2-EnvGen.ar(Env.asr(dec, 1, 0, 0), Trig.ar(begin, sustain), doneAction:2))
        * EnvGen.ar(Env.asr(0, 1, rel, 0), Trig.ar(begin, sustain-rel), doneAction:2)
    );
    var gain = lenv*( lenv*(end+pk-(2*sus))/2 + (-3*end-pk+(4*sus))/2 ) + end;
    var ovt = lenv*( lenv*(end_ovt+pk_ovt-(2*sus_ovt))/2 + (-3*end_ovt-pk_ovt+(4*sus_ovt))/2 ) + end_ovt;
    var oct = lenv*( lenv*(end_oct+pk_oct-(2*sus_oct))/2 + (-3*end_oct-pk_oct+(4*sus_oct))/2 ) + end_oct;
    var sound = f[\sincosci].(freq*(2**oct), ovt+1, mul:gain*pi).sin;
    OffsetOut.ar(out, DirtPan.ar(sound, d.numChannels, pan, renv))
}).add;
d.soundLibrary.addSynth(
    \sinc2, (instrument:\sinc2, fadein:0.001, fadeout:0.005, att:0, dec:0, rel:0, legato:1, sustain: {
        (~delta*~legato).max(~att).max(~fadein).max(~dec) + ~rel.max(~fadeout)
    })
);
)

/*SynthDef(\adsrsynth, { |out, att=0, dec=0, sus=0.5, rel=0, curve=0, sustain, pan, freq|
    var begin = Impulse.ar(0);
    var env = EnvGen.ar(
        Env.adsr(att, dec, sus, rel, 1, curve),
        Trig.ar(begin, sustain-rel));
    var sound = ...*env;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan))
}).add;
~dirt.soundLibrary.addSynth(\adsrsynth,
    (instrument:\adsrsynth, att:0, dec:0, rel:0, legato:1, sustain: {
        (~delta*~legato).max(~att+~dec)+~rel}));
*/

(
~amb0 = {
    0
};

~amb1 = {
    GVerb.ar(
		HPF.ar(Mix.new(~orbit1.ar), freq:60),
		roomsize:40, revtime:3, damping:0.5, spread:10,
		earlyreflevel: 0.2,
		drylevel:0, mul:0.1
)
};

~amb2 = {
    GVerb.ar(
	   HPF.ar(Mix.new(~orbit2.ar), freq:200),
		roomsize:70, revtime:2, damping:0.6, spread:1,
		earlyreflevel: 0.1,
		drylevel:0, mul:0.05
)
};

// ~preout = ~orbit0 + ~orbit1 + ~orbit2;
~preout = ~orbit0 + ~orbit1 + ~orbit2 + ~amb0 + ~amb1 + ~amb2;
~out = {Limiter.ar(0.5*~preout.ar)};
)

s.record("~/record/2018-05-25-sketch.wav", 0);
s.stopRecording;

s.quit