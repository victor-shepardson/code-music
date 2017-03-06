(
s.options.blockSize = 32;
s.options.numInputBusChannels = 4;
s.options.numOutputBusChannels = 4;
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
)

(
p.clear;

p[\gain] = 1.0;
p[\gain] = 2.sqrt;
p[\gain] = 2.sqrt*0.995;

p[\in].ar(3);
p[\in] = {In.ar(1,3)};

p[\fb].ar(3);
p[\del].ar(3);
p[\del] = {DelayC.ar(p[\fb].ar, maxdelaytime:1, delaytime:3e-1*[0.02, 0.015, 0.017])};
p[\filt] = {BLowPass.ar(p[\del].ar, 14000, 4)};
p[\shift] = {FreqShift.ar(p[\filt].ar, 1e-1*[0-7, 11, 0-3])};
// p[\fb] = {p[\gain]*~squash.(LeakDC.ar(MatMul.ar(~randmat.value, p[\shift].ar))) + p[\in].ar};
p[\fb] = {p[\gain]*~squash.(LeakDC.ar(MatMul.ar(~fbmat.(p[\fb].ar), p[\shift].ar))) + p[\in].ar};

p[\preout].ar(2);
p[\out].ar(2);
p[\aux].ar(2);
p[\out].play;
p[\aux].play(2);

p[\preout] = {Splay.ar(p[\fb].ar)};
// p[\preout] = {Splay.ar(p[\in].ar)};

// p[\out] = {FreeVerb.ar(Limiter.ar(BHiPass4.ar(p[\preout].ar, 20, 1.5)), mix:0.07, room:0.75, damp:0.2)};
p[\out] = {Limiter.ar(BHiPass4.ar(p[\preout].ar, 20, 1.5))};

p[\aux] = p[\preout];
)

b = Buffer.alloc(s, 262144, 2);
b.write("~/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples/live/9.wav".standardizePath, "wav", "int16", 0, 0, true);
p[\disk] = {DiskOut.ar(b, p[\out].ar)};
b.close;
b.free;