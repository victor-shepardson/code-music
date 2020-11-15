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

(
d.loadSoundFiles("~/Music/sample/dirt/*");

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

d.orbits.do { |x|
    x.globalEffects = x.globalEffects.addFirst(
        GlobalDirtEffect(\monosynth, [\monofreq, \monogain, \monolag, \monopan])
    )
};
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

(1..SuperDirt.maxSampleNumChannels).do { |numChannels|
    SynthDef("monosynth"++numChannels, {
    |dryBus, effectBus, monofreq=0, monogain=0, monopan=0, monolag=0.01|
        var in, snd;

        in = In.ar(dryBus, d.numChannels);

        snd = SinOsc.ar(Lag.kr(monofreq, monolag)).sin*Lag.kr(monogain, monolag);

        snd = DirtPan.ar(snd, numChannels, Lag.kr(monopan, monolag));

        Out.ar(effectBus, snd+in);
    }, [\ir, \ir]).add;
};

// d.orbits.do { |x| x.globalEffects.postln }
)

d.orbits.do({ |x| x.initNodeTree });

// d.orbits.do { |x|
//     x.globalEffects = x.globalEffects[0] = (
//         GlobalDirtEffect(\monosynth, [\monofreq, \monogain])
//     )
// };


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
		roomsize:100, revtime:1.5, damping:0.7, spread:5,
		earlyreflevel: 0.0,
		drylevel:0, mul:0.05
)};

~amb2 = {
    f[\wiggle].(
        GVerb.ar(
            HPF.ar(Mix.new(~orbit2.ar), freq:60),
            roomsize:40, revtime:2.5, damping:0.6, spread:90,
            earlyreflevel: 0.2,
            drylevel:0, mul:0.08
        ), dry:0.0, rate:1/3, amt:0.003
)};

~preout = ~fx0 + ~fx1 + ~fx2 + ~amb0 + ~amb1 + ~amb2;
// ~preout = ~orbit0 + ~orbit1 + ~orbit2;
~out = {Limiter.ar(0.7*~preout.ar)};
)

thisProcess.platform.recordingsDir
s.record
s.stopRecording

s.quit