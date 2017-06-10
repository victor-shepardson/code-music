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

//wild guess at a 2-d vowel space filter
~formant = {|in, x1, x2|
	var f1 = x1*600 + 250,
	f2 = x2*2000 + 50 + f1,
	f3 = x1*x2*1100 + 2200,
	f = [f1,f2,f3].max(30).min(12000),
	r = 2*[0.2,0.15,0.1],
	g = [1, 0.1, 0.05]/r.sqrt,
	formants = Resonz.ar(in, f,r,g);
	formants = Resonz.ar(formants, f,r,g);
	formants = Resonz.ar(formants, f,r,g);
	Mix.ar(formants)
};

//wild guess at a 2-d vowel space filter
~broadformant = {|in, x1, x2|
	var f1 = x1*600 + 250,
	f2 = x2*2000 + 50 + f1,
	f3 = x1*x2*1100 + 2200,
	f = [f1,f2,f3].max(30).min(12000),
	r = 0.5*[0.2,0.15,0.1],
	g = [1, 0.1, 0.05];
	RLPF.ar(in, f[0], r[0], g[0])+BPF.ar(in, f[1], r[1], g[1])+RHPF.ar(in, f[2], r[2], g[2])
};

SynthDef(\grain, { |out, sustain = 0.05, pitch1 = 440, pitch2 = 0, pitch3 = 0, amp = 1, pan = 0, width = 0.2, tilt=0|
	var ramp = LFSaw.ar(1/sustain, 1).range(0,1),
	pitch = 2**(ramp*(pitch3-pitch2)+pitch2)*pitch1,
	sound = SinOsc.ar(pitch, 0.5pi),
	rampexp = 2**(0-tilt),
	bpramp = ramp**rampexp*2-1,
	env = exp(bpramp*bpramp/(-2.0*width*width));
	OffsetOut.ar(out,
		DirtPan.ar(env * sound, ~dirt.numChannels, pan, amp)
	)
}).add;

SynthDef(\buzzgrain, { |out, sustain = 0.05, pitch1 = 440, pitch2 = 0, pitch3 = 0, amp = 1, pan = 0, width = 0.2, tilt=0, partials=16|
	var ramp = LFSaw.ar(1/sustain, 1).range(0,1),
	pitch = 2**(ramp*(pitch3-pitch2)+pitch2)*pitch1,
	sound = Blip.ar(pitch, partials),
	rampexp = 2**(0-tilt),
	bpramp = ramp**rampexp*2-1,
	env = exp(bpramp*bpramp/(-2.0*width*width));
	OffsetOut.ar(out,
		DirtPan.ar(env * sound, ~dirt.numChannels, pan, amp)
	)
}).add;

SynthDef(\fm, { |out, sustain = 0.05, pitch1 = 440, pitch2 = 110, pitch3 = 0, amp = 1, pan = 0, tilt=0, index=1, stiff=0|
	var ramp = Sweep.ar(1),//LFSaw.ar(1/sustain, 1).range(0,1),
	env = (0-ramp*tilt).exp,//(1-ramp)**tilt,
	penv = 2**(0.05*env),
	mod = SinOsc.ar(pitch2)*env,
	fund = SinOsc.ar((2**(mod*index))*pitch1*penv+stiff)*env;
	OffsetOut.ar(out,
		DirtPan.ar(fund, ~dirt.numChannels, pan, amp)
	)
}).add;

SynthDef(\fm2, { |out, sustain = 0.05, pitch1 = 440, pitch2 = 0, pitch3 = 0, amp = 1, pan = 0, tilt=0, index=1, bounce=0.05, ratio=1|
	var ramp = Sweep.ar(1),
	env = (0-ramp*tilt).exp*(ramp*3000).min(1),
	penv = 2**(bounce*env),
	mod = SinOsc.ar(pitch1*ratio)*env*SinOsc.ar(pitch3, 0, 0.5, 0.5),
	fund = SinOsc.ar((2**(mod*index))*pitch1*penv+pitch2)*env;
	OffsetOut.ar(out,
		DirtPan.ar(fund, ~dirt.numChannels, pan, amp)
	)
}).add;

SynthDef(\fm3, { |out, sustain = 0.05, pitch1 = 440, pitch2 = 0, pitch3 = 0, amp = 1, pan = 0, decay=0, index=1, bounce=0.05, ratio=1, partials=1, glide=0, formant1=0.5, formant2=0.5|
	var ramptime=0.003,
	rampin = Sweep.ar(1,1/ramptime).min(1),
	ramp = Sweep.ar(rampin>=1),
	rampout = 0,//Sweep.ar(ramp>sustain-(2*ramptime), 1/ramptime).min(1),
	dsign = (decay>0)*2-1,
	env = rampin * (0-ramp*decay.abs).exp*dsign+(decay<0) * (1-rampout),
	penv = 2**(bounce*env),
	venv = 1-(0-ramp*glide.abs).exp,
	mod = SinOsc.ar(pitch1*ratio)*env*SinOsc.ar(pitch3, 0, 0.5, 0.5),
	fund = Blip.ar((2**(mod*index))*pitch1*penv+pitch2, partials),
	sound = ~broadformant.(fund, venv*glide + formant1, venv*glide+formant2);
	OffsetOut.ar(out,
		DirtPan.ar(sound*env, ~dirt.numChannels, pan, amp)
	)
}).add;

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

p[\cps] = 0.51;
p[\dtime0] = 1/p[\cps]/4;
p[\dtime1] = 1/p[\cps]/2;
p[\dtime2] = 1/p[\cps]/1;
p[\damt] = 0.7;

/*p[\env0].ar(1);
p[\env0] = {~change.(p[\orbit0].ar)};
p[\env0].scope;*/

p[\amp0].ar(1);
p[\amp0] = {Amplitude.ar(Mix.ar(p[\orbit0].ar),  p[\dtime1], p[\dtime1])};
p[\fb0].kr(1);
p[\fb0] = {1-exp(p[\amp0].kr**2*(0-200))};
/*
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

p[\verb1].ar(2);
p[\verb1in] = p[\orbit1];
p[\verb1] = {FreeVerb.ar(~tanh.(p[\verb1in].ar, 8*(1-p[\fb0].ar)), mix:1, room:p[\fb0].ar, damp: 1)};

p[\verb2].ar(2);
p[\verb2in] = p[\orbit2];
p[\verb2] = {FreeVerb.ar(~tanh.(p[\verb2in].ar, 8), mix:1, room:0.8, damp:0.8)*(p[\fb0].ar*0.7+0.3)};



p[\worbit0].ar(2);
p[\worbit0] = {~wiggle.(p[\orbit0].ar, amt:0.002, rate:5)};
//
p[\worbit1].ar(2);
p[\worbit1] = {~wiggle.(p[\orbit1].ar+(0.2*p[\verb1]), amt:0.01, rate:0.25)};
//
p[\worbit2].ar(2);
p[\worbit2] = {~wiggle.(p[\orbit2].ar, amt:0.04, rate:1)};
//
//
// p[\shifted].ar(2);
// p[\shifted] = {FreqShift.ar(p[\in].ar, Amplitude.ar(p[\in].ar.reverse)*20)};

p[\preout] = p[\worbit0] + p[\worbit1] + p[\worbit2] + (0.2*p[\verb2]);
// p[\preout] = p[\orbit0] + p[\orbit1] + p[\orbit2];
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