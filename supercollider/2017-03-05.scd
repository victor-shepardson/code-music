s.quit

(
s.options.blockSize = 64;
s.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
s.options.memSize = 8192 * 128; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
s.options.numOutputBusChannels = 4; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 2; // set this to your hardware input channel size, if necessary
// boot the server
s.waitForBoot({
	~dirtchannels = 2;
	~dirtorbits = 3;
	~dirtbus = Bus.audio(s, ~dirtchannels*~dirtorbits);

	//start SuperDirt
	~dirt = SuperDirt(~dirtchannels, s);
	~dirt.loadSoundFiles;   // load samples (path containing a wildcard can be passed in)
	//s.sync; // wait for samples to be read
	~dirt.start(57120,
		Array.fill(~dirtorbits, {|i| i*~dirtchannels+~dirtbus.index}));   // start listening on port 57120, create one orbit which sends to ~dirtbus

	p = ProxySpace.push(s);
	p.pop;
})
)

(
SynthDef(\grain, { |out, sustain = 0.03, freq = 440, amp = 1, pan = 0, width = 0.3, accelerate =100|
	var env, sound;
	sound = SinOsc.ar(accelerate, 0.5pi);
	env = LFGauss.ar(sustain, width, loop: 0).range(0, 1);
	OffsetOut.ar(out,
		DirtPan.ar(env * sound, ~dirt.numChannels, pan, amp)
	)
}).add;
)

(
// v-deep frequency modulation of h-wide sine wave clusters
~wiggle = {|in, amt=0.001, rate=1, h=4, v=2, hratio=0.125pi, hdecay=0.5, vratio=32, shape=1|
	var norm = Array.fill(h, {|i| hdecay**i}).sum,
	cluster = {|r, m| Mix.fill(h, {|i|
		SinOsc.ar(r*(hratio**i)*(2**m),0,hdecay**i)
	})/norm},
	wave = 0, z = 0;
	for (0,v-1,{ |i|
		wave = cluster.(rate*(vratio**(i-v+1)), wave*shape);
	});
	DelayC.ar(in, 3*amt, (wave+1)*amt/2+(SampleDur.ir*4))
};

// nice sounding fader with a linearish control
~fader = {|in, x|
	var xc = Clip.kr(x),
	hp = HPF.ar(in, 2**(0-xc*4)*300),
	lp = LPF.ar(hp, 2**(xc*6)*300);
	xc*lp
};

~tanh = {|in, drive=1|
	2/(1+exp(0-drive*in))-1
};

~change = {|in|
	var mono= Mix.ar(in),
	freqs = [60,120,240,500,1000,2000,4000,8000,16000],
	bands = (BBandPass.ar(mono, freqs, bw:0.125).abs*AmpComp.ir(freqs, freqs[0]))**0.25,
	envs = Amplitude.ar(bands, 0.03, 0.03),
	//envs2 = Amplitude.ar(bands, 1, 1),
	//deltas = HPZ1.kr(A2K.kr((envs-envs2).max(0))),
	deltas = HPZ1.kr(A2K.kr(envs)),
	curves = Amplitude.kr(deltas.abs**1, 0.03, 0.03);

	curves.scope;
	Mix.kr(curves)
};
)

(
p.clear();
p[\preout].ar(2);
p[\out].ar(2);
p[\out].play;
p[\aux].ar(2);
p[\aux].play(2);

//get external input
p[\in] = {SoundIn.ar([0,1])};
// p[\dirt] = NodeProxy.for(~dirtbus);

//split ~dirtbus into orbits
for(0,~dirtorbits-1,{|i|
	var id = ['orbit', i].join.asSymbol;
	id.postln;
	p[id].ar(~dirtchannels);
	p[id] = {InBus.ar(~dirtbus, ~dirtchannels, ~dirtchannels*i)};
});

p[\cps] = 1.0;
p[\dtime0] = 1/p[\cps]/6;
p[\dtime1] = 1/p[\cps]/3;
p[\dtime2] = 1/p[\cps]/1.5;
p[\damt] = 0.7;

/*p[\env0].ar(1);
p[\env0] = {~change.(p[\orbit0].ar)};
p[\env0].scope;*/

/*p[\amp0].ar(1);
p[\amp0] = {Amplitude.ar(Mix.ar(p[\orbit0].ar),  p[\dtime1], p[\dtime1])};
p[\fb0].kr(1);
p[\fb0] = {1-exp(p[\amp0].kr**2*(0-200))};

p[\amp1].kr(1);
p[\amp1] = {Amplitude.kr(Mix.ar(p[\orbit1].ar), p[\dtime2], p[\dtime2])};
p[\fb1].kr(1);
p[\fb1] = {1-exp(p[\amp1].kr**2*(0-200))};

p[\amp2].kr(1);
p[\amp2] = {Amplitude.kr(Mix.ar(p[\orbit2].ar), p[\dtime0], p[\dtime0])};
p[\fb2].kr(1);
p[\fb2] = {1-exp(p[\amp2].kr**2*(0-200))};*/

// p[\dorbit0].ar(2);
// p[\dorbit0] = {FreqShift.ar(p[\orbit0].ar+DelayC.ar(~fader.(p[\dorbit0].ar, p[\damt]), 10, p[\dtime0]), 0+100*p[\fb1].kr)};
//
// p[\dorbit1].ar(2);
// p[\dorbit1] = {FreqShift.ar(p[\orbit1].ar+DelayC.ar(~fader.(p[\dorbit1].ar, p[\damt]), 10, p[\dtime1]), 0-33*p[\fb2].kr)};
//
// p[\dorbit2].ar(2);
// p[\dorbit2] = {FreqShift.ar(p[\orbit2].ar+DelayC.ar(~fader.(p[\dorbit2].ar, p[\damt]), 10, p[\dtime2]), 0-67*p[\fb0].kr)};

/*p[\verb].ar(2);
p[\verbin] = p[\orbit0];
p[\verb] = {FreeVerb.ar(~tanh.(p[\verbin].ar*p[\fb1].ar, 8), mix:1, room:0.8)*(p[\fb0].ar*0.7+0.3)};*/



// p[\worbit0].ar(2);
// p[\worbit0] = {~wiggle.(p[\orbit0].ar, amt:0.003, rate:5)};
//
// p[\worbit1].ar(2);
// p[\worbit1] = {~wiggle.(p[\orbit1].ar, amt:0.03, rate:1)};
//
// p[\worbit2].ar(2);
// p[\worbit2] = {~wiggle.(p[\orbit2].ar, amt:0.03, rate:1)};
//
//
// p[\shifted].ar(2);
// p[\shifted] = {FreqShift.ar(p[\in].ar, Amplitude.ar(p[\in].ar.reverse)*20)};

p[\preout] = p[\orbit0] + p[\orbit1] + p[\orbit2];
// p[\preout] = p[\shifted];
// p[\preout] = p[\in];

// p[\preout] = {FreeVerb.ar(Convolution.ar(p[\orbit0].ar, p[\in].ar, 8192, 0.5)) + p[\dorbit1].ar + p[\worbit2].ar};

// p[\preout] = {Convolution.ar(p[\orbit0].ar, p[\in].ar, 8192, 0.5) + p[\dorbit1].ar + p[\worbit2].ar};

p[\out] = {FreeVerb.ar(Limiter.ar(BHiPass4.ar(p[\preout].ar, 20, 1.5)), mix:0.07, room:0.75, damp:0.2)};
// p[\out] = {Limiter.ar(BHiPass4.ar(p[\preout].ar, 20, 1.5)), mix:0.1, room:0.75, damp:0.2};

p[\aux] = p[\preout];
)


// r = p.record(\out, "~/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples/live/7.wav".standardizePath, "wav", "int16");
// r.unpause
// r.pause
// r.close
b = Buffer.alloc(s, 262144, 2);
b.write("~/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples/live/7.wav".standardizePath, "wav", "int16", 0, 0, true);
p[\disk] = {DiskOut.ar(b, p[\out].ar)};
b.close;
b.free;


SuperDirt.stop

s.quit