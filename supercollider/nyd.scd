(
s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.options.numWireBufs = 128;
s.boot
)

s.quit

p = ProxySpace.push(s);

(
p.clear;
~out.ar(2);
~out.play;

// wiggler
w = {|src, amt|
	var lfos = Array.fill(src.size, {
		var freq = Lag.kr(Trig.kr(Dust.kr(1, 4)),4) + SinOsc.kr(0.2,0,2,3);
		Lag.ar(Trig.ar(Dust.ar(freq*0.5)),2) + SinOsc.ar(freq, 0, 0.5, 0.5)
	});
	DelayC.ar(src, 2, lfos*amt)
};

// sinc function
n = {|phi| phi.sin / phi.abs.max(1e-15) * (phi>0 *2 -1)};

// sinc oscillator
o = {|freq, band|
	var phi = Phasor.ar(0, 2*freq/SampleRate.ir, -1, 1),
	scale = (band+0.5)*1pi - (1/((band+0.5)*1pi));
	n.(phi*scale)
};

// sinc oscillator + sin waveshaper
m = {|freq, band, gain|
	var sinc = o.(freq, band);
	(gain*sinc*0.5pi).sin
};

// sinc-sin terrain oscillator
c = {|freq, xdisp, ydisp, xstretch, ystretch|
	var phi = Phasor.ar(0, 2*freq/SampleRate.ir, -1, 1),
	xpos = (1pi*phi).cos * xstretch + xdisp,
	ypos = (1pi*phi).sin * ystretch + ydisp,
	sinc = n.(xpos);
	(ypos*sinc*0.5pi).sin
};

// sinc-sin terrain oscillator v2
d = {|xfreq, yfreq, xdisp, ydisp, xstretch, ystretch|
	var xphi = Phasor.ar(0, 2*xfreq/SampleRate.ir, -1, 1),
	yphi = Phasor.ar(0, 2*yfreq/SampleRate.ir, -1, 1),
	xpos = (1pi*xphi).cos * xstretch + xdisp,
	ypos = (1pi*yphi).sin * ystretch + ydisp,
	sinc = n.(xpos);
	(ypos*sinc*0.5pi).sin
};

// sinc-sin terrain oscillator v3
z = {|freq, xstretch, ystretch|
	var phi = Phasor.ar(0, 2*freq/SampleRate.ir, -1, 1),
	xpos = (1pi*phi).cos * xstretch,
	ypos = (1pi*phi).sin+1 * ystretch,
	sinc = n.(xpos);
	(ypos*sinc*pi).sin
};

//apply evenly spaced cosine windows to list of UGens
e = {|src, freq|
	var num = src.size,
	envs = Array.fill(num, {|i| SinOsc.ar(freq, 2pi/num*i+(3pi/2), 0.5, 0.5)});
	src*envs
};

//generate evenly spaced linear ramps
r = {|num, freq, mul=1, add=0| Array.fill(num, {|i|
	LFSaw.ar(freq, 2*i/num*(freq>0*2-1), 0.5, 0.5)*mul + add
})};


v=8;
~sfund = 15;
~sfreq = (-0.0005);
//~mfund = 10;
~dfund = 15;
~di = 3/2;

// ~mfund = 10;
// ~dfund = 10;
// ~i = 4/3;

//~mfund = 5;
// ~dfund = 10;
// ~i = 15/8;

// ~mfund = 5;
// ~dfund = 10;
~si = 3/2;

~wamt = 0.0001;

// ~modenv = {Array.fill(v, {|i| Decay2.ar(
// 	Dust.ar(0.9**(0-i)*0.03*SinOsc.ar(1/(i+10).nthPrime, 3pi/2, 1, 1)),
// 	1.1**(0-i)*0.1,
// 	1.1**(-1*i)*32)
// })};
// ~modsrc.fadeTime=4;
// ~modsrc = {Array.fill(v, {|i| m.(~i**i*~mfund,v-i,(v-i)*~modenv.ar[i])}).scramble};
// ~del = {w.(~modsrc.ar, ~wamt)};
// ~mod = {Limiter.ar(Splay.ar(~del.ar))};
//
// ~modenv2 = {Array.fill(v, {|i| Decay2.ar(
// 	Dust.ar(0.9**(0-i)*0.03*SinOsc.ar(1/(i+10).nthPrime, 3pi/2, 1, 1)),
// 	1.1**(0-i)*0.1,
// 	1.1**(-1*i)*32)
// }).reverse};
// ~modsrc2.fadeTime=4;
// ~modsrc2 = {Array.fill(v, {|i| m.(~i**i*~mfund,v-i,(v-i)*~modenv2.ar[i])}).scramble};
// ~del2 = {w.(~modsrc2.ar, ~wamt)};
// ~mod2 = {Limiter.ar(Splay.ar(~del2.ar))};

// ~drone = {Limiter.ar(Splay.ar(Array.fill(8, {|i| 0.5*(0.8**i)*c.(
// 	~di**i*~dfund,
// 	SinOsc.kr(1/(5+i+24).nthPrime, 3pi/2, 3, 3),
// 	SinOsc.kr(1/(5+i+16).nthPrime, 3pi/2, 3, 3),
// 	SinOsc.kr(1/(5+i+8).nthPrime, 3pi/2, 3, 3.01),
// 	SinOsc.kr(1/(5+i).nthPrime, 3pi/2, 3, 3.01)
// )}).scramble))};

// v = 8;
// ~pulse = 0.25;
// ~xmag = 2;
// ~ymag = 1;
// ~xmag2 = 2;
// ~ymag2 = 1;
// ~dfund2 = 90;
// ~drone2 = {Limiter.ar(Splay.ar(Array.fill(v, {|i| 0.5*(0.8**i)*d.(
// 	~dfund2*(i.nthPrime).nthPrime/i.nthPrime,
// 	~dfund2*i.nthPrime,
// 	SinOsc.kr(~pulse/(5+i+(3*v)).nthPrime, 3pi/2, ~xmag2, ~xmag2),
// 	SinOsc.kr(~pulse/(5+i+(2*v)).nthPrime, 3pi/2, ~ymag2, ~ymag2),
// 	SinOsc.kr(~pulse/(5+i+v).nthPrime, 3pi/2, ~xmag, ~xmag),
// 	SinOsc.kr(~pulse/(5+i).nthPrime, 3pi/2, ~ymag, ~ymag)
// )}).scramble))};

~spulse = 2;
~spulse2 = 1;
~shepard = {
	var ramps = r.(v, ~sfreq),
	envs = 0.5-(0.5*(2pi*ramps).cos);
	Limiter.ar(Splay.ar(e.(Array.fill(v, {|i| (0.8**i)*z.(
		~si**(v*ramps[i])*~sfund,
		envs[i]*SinOsc.kr(~spulse/(5+i+v).nthPrime, 3pi/2, 2, 3)/(i+1),
		envs[i]*SinOsc.kr(~spulse/(5+i).nthPrime, 3pi/2, 0.5, 0.5)
	)}).scramble, ~spulse2).scramble))
};

~shepard2 = {
	var ramps = r.(v, ~sfreq*SinOsc.ar(1/32)*4),
	envs = 0.5-(0.5*(2pi*ramps).cos);
	Limiter.ar(Splay.ar(e.(Array.fill(v, {|i| (0.8**i)*z.(
		~si**(v*ramps[i]+2)*~sfund,
		envs[i]*SinOsc.kr(~spulse/(2*v+5+i).nthPrime, 3pi/2, 2, 3)/(i+1),
		envs[i]*SinOsc.kr(~spulse/(4*v+5+i).nthPrime, 3pi/2, 0.5, 0.5)
	)}).scramble, ~spulse2*3)))
};

~shepard3 = {
	var ramps = r.(v, ~sfreq*SinOsc.ar(1/43)*2),
	envs = 0.5-(0.5*(2pi*ramps).cos);
	Limiter.ar(Splay.ar(e.(Array.fill(v, {|i| 0.25*(0.9**i)*z.(
		~si**(v*ramps[i]+4)*~sfund,
		envs[i]*SinOsc.kr(~spulse/(3*v+5+i).nthPrime, 3pi/2, 2, 3)/(i+1),
		envs[i]*SinOsc.kr(~spulse/(5*v+5+i).nthPrime, 3pi/2, 0.5, 0.5)
	)}), ~spulse2*2).scramble))
};

// ~preout = ~drone2+~shepard*0.5+~drone;
~preout = ~shepard3+~shepard2*0.5+~shepard;
// ~preout = ~shepard;
// ~preout = ~drone2;

// ~preout = {~mod.ar+~mod2.ar*0.5+~drone.ar};
// ~preout = {~drone.ar};
// ~preout = {~drone2.ar*0.5+~drone.ar};
// ~preout = {~mod.ar};

~out = {Limiter.ar(HPF.ar(~preout.ar, 20))};
)

~dummy.scope

6.nthPrime
1.5**7*15
~preout.scope