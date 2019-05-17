(
s.options.blockSize = 32;
s.options.numInputBusChannels = 4;
s.options.numOutputBusChannels = 4;
s.options.memSize = 8192 * 128;
s.boot
)
s.quit

p = ProxySpace.push;
p.pop

(
~randmat = {FBMat.ar(Array.fill2D(3,3,{|r,c|
	LFBrownNoise2.ar(1)
}))};
~fbmat = {|fb|
	var ps = 0.03/[1, 1.exp, 2.sqrt/2],
	time = 2e-1;
	FBMat.ar(Array.fill2D(3,3,{|r,c|
		Amplitude.ar(CombC.ar(fb.wrapAt(r+1), delaytime:ps[c], decaytime: time), time/4, time/4)
}))};
~squash = {|x|
	x*(0.7-Amplitude.ar(x, 0.005, 0.01)).min(0).exp
};
~amdelay = {|x, t|
	var extra = SampleDur.ir*BlockSize.ir,
	mod = SinOsc.ar(0.5/t.abs, 0, 1, 1),
	del = t.sign*DelayC.ar(x*mod, 10, t.abs-extra);
	BLowShelf.ar(del,1000, 2, 0-3)
};
~fbdelay = {|x, t|
	var extra = SampleDur.ir*BlockSize.ir,
	del = t.sign*DelayC.ar(x, 10, t.abs-extra);
	del;//BLowShelf.ar(del, 1000, 2, 0-1)
};
)
(
p.clear();
p[\preout].ar(2);
p[\out].ar(2);
p[\out].play;
p[\aux].ar(2);
p[\aux].play(2);

// ~dtime = 0.5/[7, -8, 9, -11, 13, -17, 19];
~dtime = [7, -8, 9, -11, 13, -17, 19]/50;
// p[\gain] = 2.sqrt/2;
// p[\gain] = 2*0.99;
p[\gain] = 1.0/~dtime.size;
p[\gain] = 2/~dtime.size;

// p[\gain] = 2.sqrt;
// p[\gain] = 2.sqrt*0.995;

// p[\in].ar(3);
// p[\in] = {SoundIn.ar([0,2,1])};
p[\in].ar(2);
p[\in] = {SoundIn.ar([0,1])};

p[\fb].ar(2);
p[\del].ar(2);

p[\env].kr(2);
p[\env] = {A2K.kr(Amplitude.ar(p[\in].ar, 0.01, 0.05))};
p[\env2].ar(2);
p[\env2] = {Amplitude.ar(p[\in].ar, 0.003, 1)};
p[\env3].ar(2);
p[\env3] = {Amplitude.ar(p[\del], 0.1, 0.1)};

// p[\fb].ar(3);
// p[\del].ar(3);
// p[\del] = {DelayC.ar(p[\fb].ar, maxdelaytime:1, delaytime:1e-1*[0.02, 0.015, 0.017])};
// p[\filt] = {BLowPass.ar(p[\del].ar, 14000, 4)};
// p[\shift] = {FreqShift.ar(p[\filt].ar, 1e-1*[0-7, 11, 0-3])};
// p[\fb] = {p[\gain]*~squash.(LeakDC.ar(MatMul.ar(~randmat.value, p[\shift].ar))) + p[\in].ar};
// p[\fb] = {p[\gain]*~squash.(LeakDC.ar(MatMul.ar(~fbmat.(p[\fb].ar), p[\shift].ar))) + p[\in].ar};

p[\del] = {(p[\env2].ar.sqrt+1)/(1+p[\env3].ar)*Mix.fill(~dtime.size, {|i|
	~amdelay.(p[\fb].ar, ~dtime[i]*(0-(p[\env].kr**2*4)).exp)
})};
/*p[\del] = {Mix.fill(~dtime.size, {|i|
	~fbdelay.(p[\fb].ar, ~dtime[i]*(0-(p[\env].kr**2)).exp)
	})};*/
p[\fb] = p[\del]*p[\gain] + p[\in];

p[\preout] = {Splay.ar(p[\del].ar)+p[\in].ar};
// p[\preout] = {Splay.ar(p[\in].ar)};

// p[\out] = {FreeVerb.ar(Limiter.ar(BHiPass4.ar(p[\preout].ar, 20, 1.5)), mix:0.07, room:0.75, damp:0.2)};
p[\out] = {Limiter.ar(BHiPass4.ar(p[\preout].ar, 20, 1.5))};
p[\aux] = p[\out];
)

p[\env2].scope
p[\preout].scope
p[\out].scope

b = Buffer.alloc(s, 262144, 2);
b.write("~/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples/live/9.wav".standardizePath, "wav", "int16", 0, 0, true);
p[\disk] = {DiskOut.ar(b, p[\out].ar)};
b.close;
b.free;