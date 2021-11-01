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
	~dirtorbits = 6;
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

d.modules

(
d.loadSoundFiles("~/Music/sample/dirt/*");

d.orbits.do { |x|
    x.globalEffects = x.globalEffects.addFirst(
        GlobalDirtEffect(\monosynth, [
            \monofreq, \monogain, \monolag, \monopan, \monostretch, \monospread,
            \monodrive, \monoindex, \monoratio
        ]))
};


//proxyspace
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

/*~in = {SoundIn.ar([2,3])};
~ml = {MFCC.kr(FFT(LocalBuf(1024), ~in.ar[0]))};
~mr = {MFCC.kr(FFT(LocalBuf(1024), ~in.ar[1]))};

r = {
    inf.do {
        ~ml.bus.getn(13, { |val| val.do({ |v, i| n.sendMsg('/ctrl', ['ml_',i].join, v) }) });
        ~mr.bus.getn(13, { |val| val.do({ |v, i| n.sendMsg('/ctrl', ['mr_',i].join, v) }) });
        0.04.wait; // 25 frames per second
    }
}.fork;*/

)

(
//synths and patchable effects
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


f[\sinsincos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0)*pi,
    fold_wave = (phi.sin*ratio*pi).sin,
    cos_env = phi.cos +1 /2;
    fold_wave * cos_env
    };

f[\sincos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0)*pi,
    fold_wave = phi.sin*ratio*pi,
    cos_env = phi.cos +1 /2;
    fold_wave * cos_env
};

f[\stretch] = {
    arg freq, ratio, osc ...oscargs;
    FreqShift.ar(osc.(freq*ratio, *oscargs), 0-(ratio -1 *freq))
};

DirtPan.defaultPanningFunction = { | signals, numChannels, pan, mul |
    // var channels, inNumChannels;
    if(numChannels > 2) {
        DirtSplayAz.ar(
            numChannels,
            signals,
            \span.ir(1),
            pan,
            mul,
            \splay.ir(1),
            \panwidth.ir(2),
            \orientation.ir(0)
        )
    } {
        //DirtSplay2.ar(signals, \span.ir(1), pan, mul)
        // DirtPanBalance2.ar(signals, \span.ir(1), pan, mul)
        var max_time = 0.03;
        var min_time = SampleDur.ir * 4.;
        var left_delay = pan.max(min_time) * max_time;
        var right_delay = 0-pan.min(min_time);
        if (numChannels==1) {signals = [signals[0], signals[0]]*0.71};
        DelayC.ar(signals, max_time, [left_delay, right_delay], mul:mul);
    }
}

(1..SuperDirt.maxSampleNumChannels).do { |numChannels|
    SynthDef("monosynth"++numChannels, {
    |dryBus, effectBus, monofreq=0, monogain=0, monopan=0, monolag=0.01, monostretch=1,
     monospread=0, monodrive=1, monoindex=0, monoratio=1|
        var in = In.ar(dryBus, d.numChannels);
        var warp = \sine;
        var p = 4;
        var freq = VarLag.kr(monofreq**(1/p), monolag, warp:warp)**p;
        var gain = VarLag.kr(monogain**(1/p), monolag, warp:warp)**p;
        var spread = VarLag.kr(monospread, monolag, warp:warp);
        var stretch = VarLag.kr(monostretch, monolag, warp:warp);
        var drive = VarLag.kr(monodrive.abs, monolag, warp:warp);
        var pan = VarLag.kr(monopan, monolag, warp:warp);
        var ratio = VarLag.kr(monoratio, monolag, warp:warp);
        var index = VarLag.kr(monoindex, monolag, warp:warp);
        var mod = SinOsc.ar(freq*ratio)*index;

        // var snd = SinOsc.ar(freq).sin*gain;
        var snd = {Mix.ar(f[\stretch].(
            freq+mod, stretch*[2**spread, 2**(0-spread)], f[\sinsincos], drive))
        };
        var dmix = 1.min(drive);
        // snd = (1-dmix *snd) + (dmix * (snd*pi*1.max(drive)).sin);
        snd = snd*gain;

        snd = DirtPan.ar(snd, numChannels, pan);

        Out.ar(effectBus, snd+in);
    }, [\ir, \ir]).add;

};
)

d.orbits.do({ |x| x.initNodeTree });


(
~fx0 = {f[\wiggle].(~orbit0, rate:3, amt:0.0003)};
~fx1 = {f[\wiggle].(~orbit1, rate:2, amt:0.003, dry:0.5)};
~fx2 = {f[\wiggle].(~orbit2, rate:5, amt:0.001, dry:0.2)};
~fx3 = ~orbit3;
~fx4 = ~orbit4;
~fx5 = ~orbit5;

~amb0 = {
	GVerb.ar(
        Mix.new(~orbit0.ar+~orbit3.ar),
        roomsize:50, revtime:1.5, damping:0.9, spread:5,
        earlyreflevel: 0.0,
        drylevel:0, mul:0.03
)};

~amb1 = {
	GVerb.ar(
		HPF.ar(Mix.new(~orbit1.ar+~orbit4.ar), freq:300),
		roomsize:100, revtime:1.5, damping:0.7, spread:5,
		earlyreflevel: 0.0,
		drylevel:0, mul:0.05
)};

~amb2 = {
    f[\wiggle].(
        GVerb.ar(
            HPF.ar(Mix.new(~orbit2.ar+~orbit5.ar), freq:60),
            roomsize:40, revtime:2.5, damping:0.6, spread:90,
            earlyreflevel: 0.2,
            drylevel:0, mul:0.08
        ), dry:0.0, rate:1/3, amt:0.003
)};

~preout = ~fx0 + ~fx1 + ~fx2 + ~fx3 + ~fx4 + ~fx5 + ~amb0 + ~amb1 + ~amb2;
// ~preout = ~orbit0 + ~orbit1 + ~orbit2;
~out = {Limiter.ar(0.7*~preout.ar)};
)

thisProcess.platform.recordingsDir
s.record
s.stopRecording

s.quit