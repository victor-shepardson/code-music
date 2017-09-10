include("SuperDirt")
s.quit

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
	~dirtbusses = all {:Bus.audio(s, ~dirtchannels), i <- (1..~dirtorbits)};

	//start SuperDirt
	~dirt = SuperDirt(~dirtchannels, s);
	//load samples (path containing a wildcard can be passed in)
	~dirt.loadSoundFiles;
	//s.sync; // wait for samples to be read
	~dirt.start(57120, all {:x.index, x <- ~dirtbusses});

	//create a proxyspace
	p = ProxySpace.new;

	//create a proxy for each orbit
	for(0,~dirtorbits-1,{|i|
		var id = ['orbit', i].join.asSymbol;
		id.postln;
		p[id].ar(~dirtchannels);
		p[id] = {InBus.ar(~dirtbusses[i], ~dirtchannels)};
	});
});
)

(
f = Environment.new;
f[\wiggle] = {|in, amt=0.001, rate=1, h=3, v=2, hratio=0.25pi, hdecay=0.5, vratio=32, shape=1, dry=0|
	var norm = all{:hdecay**i, i<-(0..h-1)}.sum,
	cluster = {|r, m| Mix.fill(h, {|i|
		SinOsc.kr(r*(hratio**i)*(2**m),0,hdecay**i)
	})/norm},
	wave = 0, z = 0;
	for (0,v-1,{ |i|
		wave = cluster.(rate*(vratio**(i-v+1)), wave*shape);
	});
	dry*in + DelayC.ar(in, 3*amt, (wave+1)*amt/2+(SampleDur.ir*4))
};
f[\wigglechorus] = {|in, amt=0.001, rate=1, h=3, v=2, hratio=0.25pi, hdecay=0.5, vratio=32, shape=1, dry=0.5|
	var norm = all{:hdecay**i, i<-(0..h-1)}.sum,
	cluster = {|r, m| Splay.kr(Array.fill(h, {|i|
		SinOsc.kr(r*(hratio**i)*(2**m),0,hdecay**i)
	}))/norm},
	wave = 0, z = 0;
	for (0,v-1,{ |i|
		wave = cluster.(rate*(vratio**(i-v+1)), wave*shape);
	});
	dry*in + Splay.ar(DelayC.ar(in, 3*amt, (wave+1)*amt/2+(SampleDur.ir*4)).flatten)
};
)

(
p.push(s);
~preout.ar(2);
~out.ar(2);
~out.play;
)

(

~fx0 = {f[\wiggle].(~orbit0, rate:3, amt:0.0005)};
~fx1 = ~orbit1;
~fx2 = {f[\wiggle].(~orbit2, rate:2, amt:0.005)};
// ~fx3 = {f[\wigglechorus].(~orbit3, rate:1, amt:0.01)};

~amb0 = {
	GVerb.ar(
		Mix.new(~orbit0.ar+~fx3.ar),
		roomsize:30, revtime:1, damping:0.2, spread:5,
		earlyreflevel: 0.3,
		drylevel:0, mul:0.07
)};

~amb1 = {
	GVerb.ar(
		HPF.ar(Mix.new(~orbit1.ar), freq:300),
		roomsize:10, revtime:3, damping:0.6, spread:1,
		earlyreflevel: 0.4,
		drylevel:0, mul:0.05
)};

~amb2 = {
	GVerb.ar(
		HPF.ar(Mix.new(~orbit2.ar), freq:60),
		roomsize:40, revtime:3, damping:0.5, spread:10,
		earlyreflevel: 0.4,
		drylevel:0, mul:0.1
)};

~preout = ~fx0 + ~fx1 + ~fx2 /*+ ~fx3*/ + ~amb0 + ~amb1 + ~amb2;
// ~preout = ~orbit0 + ~orbit1 + ~orbit2 + ~amb0 + ~amb1 + ~amb2;
~out = {Limiter.ar(0.7*~preout.ar)};
)