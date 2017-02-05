(
s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.options.numWireBufs = 128;
s.boot
)

s.quit
// MIDIdef.freeAll;

p = ProxySpace.push(s);

// MIDIIn.connectAll;
// MIDIdef.noteOn(\test1, {arg ...args; "on".postln; args.postln}); // match any noteOn
// MIDIdef.noteOff(\test2, {arg ...args; "off".postln; args.postln}); // match any noteOff

// ~proxy.set(\param, value)
// ~proxy.xset(\param, value)
// ~proxy.map(\param, ~controlproxy)
// ~proxy.xmap(\param, ~controlproxy)

(
v = 10;
p.clear;
~out.ar(2);
~out.play;

w = {|src, amt|
	var lfos = Array.fill(src.size, {
		var freq = Lag.kr(Trig.kr(Dust.kr(1, 4)),4) + SinOsc.kr(0.2,0,2,3);
		Lag.ar(Trig.ar(Dust.ar(freq*0.5)),2) + SinOsc.ar(freq, 0, 0.5, 0.5)
	});
	DelayC.ar(src, 2, lfos*amt)+(0.3*src)
};

// sinc function
n = {|phi| phi.sin / phi.abs.max(1e-15) * (phi>0 *2 -1)};

//sinc oscillator
o = {|freq, band|
	var phi = Phasor.ar(0, 2*freq/SampleRate.ir, -1, 1),
	scale = (band+0.5)*1pi - (1/((band+0.5)*1pi));
	n.(phi*scale)
};

//sinc oscillator + sin waveshaper
m = {|freq, band, gain|
	var sinc = o.(freq, band);
	(gain*sinc*0.5pi).sin
};

//sinc-sin terrain oscillator
c = {|freq, xdisp, ydisp, xstretch, ystretch|
	var phi = Phasor.ar(0, 2*freq/SampleRate.ir, -1, 1),
	xpos = (1pi*phi).cos * xstretch + xdisp,
	ypos = (1pi*phi).sin * ystretch + ydisp,
	sinc = n.(xpos);
	(ypos*sinc*0.5pi).sin
};

~mfund = 10;
~dfund = 15;
~i = 3/2;

/*~mfund = 10;
~dfund = 20;
~i = 4/3;*/

/*~mfund = 5;
~dfund = 10;
~i = 15/8;*/

/*~mfund = 5;
~dfund = 10;
~i = 9/5;*/

~wamt = 0.0005;

/*~modsrc.fadeTime=4;
~modsrc = {Array.fill(v, {|i| m.(~i**i*~fund,v-i,v-i)}).scramble};
~del = {w.(~modsrc.ar, 0.001)};
~modenv = {Array.fill(v, {|i| Decay2.ar(
	Dust.ar(0.9**(0-i)*0.03*SinOsc.ar(1/(i+10).nthPrime, 3pi/2, 1, 1)),
	1.1**(0-i)*0.1,
	1.1**(-1*i)*32)
})};
~mod = {Limiter.ar(Splay.ar(~del.ar*~modenv.ar))};*/

~modenv = {Array.fill(v, {|i| Decay2.ar(
	Dust.ar(0.9**(0-i)*0.03*SinOsc.ar(1/(i+10).nthPrime, 3pi/2, 1, 1)),
	1.1**(0-i)*0.1,
	1.1**(-1*i)*32)
})};
~modsrc.fadeTime=4;
~modsrc = {Array.fill(v, {|i| m.(~i**i*~mfund,v-i,(v-i)*~modenv.ar[i])}).scramble};
~del = {w.(~modsrc.ar, ~wamt)};
~mod = {Limiter.ar(Splay.ar(~del.ar))};

~modenv2 = {Array.fill(v, {|i| Decay2.ar(
	Dust.ar(0.9**(0-i)*0.03*SinOsc.ar(1/(i+10).nthPrime, 3pi/2, 1, 1)),
	1.1**(0-i)*0.1,
	1.1**(-1*i)*32)
}).reverse};
~modsrc2.fadeTime=4;
~modsrc2 = {Array.fill(v, {|i| m.(~i**i*~mfund,v-i,(v-i)*~modenv2.ar[i])}).scramble};
~del2 = {w.(~modsrc2.ar, ~wamt)};
~mod2 = {Limiter.ar(Splay.ar(~del2.ar))};

/*~kfund = 1;
~k0 = {Trig1.ar(\kt.kr, 1/SampleRate.ir)};
// ~k0 = {Impulse.ar(0.5)};
~ke = {[0.7,1,0.6,0.5]*Decay2.ar(~k0.ar, 0.005, \dur.kr*[1.0, 0.7, 0.5, 0.3])};
~kf = {\mult.kr*~kfund*[1,2,3,4]*(2**([2,3,4,5]*(Decay2.ar(~k0.ar, [0.05, 0, 0, 0], [0.3, 0.15, 0.1, 0.05]))))};
~k1 = {~ke.ar*SinOsc.ar(~kf.ar)};
~k2 = {Limiter.ar(Mix.ar(~k1.ar)*4)};
~kick = {[~k2.ar, ~k2.ar]};

~out = ~kick*0.3;*/

// ~out = {Limiter.ar(~mod.ar+~mod2.ar*0.5)};

// ~crack = {Latch.ar(Crackle.ar(1.99),Crackle.ar(1.99))};
// ~out = {[~crack.ar, ~crack.ar]};

// ~out = {Limiter.ar(~kick.ar*0.3+Compander.ar(~mod.ar+~mod2.ar, ~kick.ar, 0.1, 1.1, 0.1, 0.01, 0.15))};

~drone = {Limiter.ar(Splay.ar(Array.fill(8, {|i| 0.5*(0.8**i)*c.(
	~i**i*~dfund,
	SinOsc.kr(1/(5+i+24).nthPrime, 3pi/2, 3, 3),
	SinOsc.kr(1/(5+i+16).nthPrime, 3pi/2, 3, 3),
	SinOsc.kr(1/(5+i+8).nthPrime, 3pi/2, 3, 3.01),
	SinOsc.kr(1/(5+i).nthPrime, 3pi/2, 3, 3.01)
)}).scramble))};

// ~out = ~drone + ~mod + ~mod2

~preout = {~mod.ar+~mod2.ar*0.5+~drone.ar};
// ~preout = {~drone.ar};
// ~preout = {~mod.ar};
// ~out = {Limiter.ar((~kick.ar*0.3)+(~mod.ar+~mod2.ar*0.5)+Compander.ar(~drone.ar, ~kick.ar, 0.2, 1.1, 0.5, 0.01, 0.19))};
~out = {Limiter.ar(HPF.ar(~preout.ar, 20))};

// ~out = ~drone;

// MIDIdef.noteOn(\on, {|val,num,chan,src| ~ke.set(\dur, val/64); ~kf.set(\mult, num); ~k0.set(\kt, 1)}); // match any noteOn
// MIDIdef.noteOff(\off, {|val,num,chan,src| ~k0.set(\kt, 0)}); // match any noteOff
)