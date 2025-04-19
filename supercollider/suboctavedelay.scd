(
s.options.numInputBusChannels = 8;
s.options.hardwareBufferSize = 64;
s.options.blockSize = 64;
s.options.inDevice =  "K-Mix";
s.options.outDevice = "K-Mix";
s.options.numWireBufs = 512;
s.options.memSize = 8192*128;
s.boot;
)

(
var rates = [0.5,0.497];
// var rates = [1/2,1/4,1/8];
Ndef(\half, {
	var bdur = 64*SampleDur.ir;
	var ramp = bdur;
	var maxt = 10;
	var in = SoundIn.ar([0]);
	//detect onsets
	var chain = FFT(LocalBuf(256), in);
    var ons = Onsets.kr(chain, 0.3, \complex);
	// delay line jumps to present on onset
	var tgl = ToggleFF.kr(ons);
	var route = [tgl, 1-tgl];
	var dt = Sweep.ar(ons*route);
	var env = Slew.ar(K2A.ar(route), 1/ramp, 1/ramp);//.lag(0.001);
	var decay = Slew.ar(K2A.ar(1-route), SampleRate.ir, 1/maxt);
	var del = Mix(rates.collect{ |r| DelayC.ar(in, maxt, dt*(1-r) + bdur)})*env*decay;
	del.sum!2
}).play;
)

(
var rates = [2];
// var rates = [2,1.997,1.003];
// var rates = [1/2,1/4];
// var rates = [2,1.5];
// var rates = [2,4,8];
Ndef(\double, {
	var bdur = 64*SampleDur.ir;
	var ramp = bdur;
	var maxt = 10;
	var in = SoundIn.ar([0]);
	//detect onsets
	var chain = FFT(LocalBuf(256), in);
    var ons = Onsets.kr(chain, 0.3, \complex, mingap:100);
	// var lastons = Latch.kr(Delay1.kr(ons), ons);
	var tgl = ToggleFF.kr(ons);
	var route = [tgl, 1-tgl];
	var dts = Sweep.ar(ons*route); // time since last two onsets
	var del = Mix(rates.collect{ |r|
		var dt =  Phasor.ar(ons, SampleDur.ir*(1-r), dts[0], dts[1], dts[0]);
		var phase = Sanitize.ar(dt - dts[0] / (dts[1]-dts[0]));
		var ramp = 1 - (phase * 2 - 1).abs;
		ramp = (ramp*100).clip(0,1);
		DelayC.ar(in, maxt, dt)*ramp;
	});
	var env = Amplitude.ar(in) / (Amplitude.ar(del)+1e-2);//Slew.ar(K2A.ar(route), 1/ramp, 1/ramp);//.lag(0.001);
	del = del * env;
	// del!2
	Mix(del)!2
}).play;
)

(
var def = {
	arg in, fs;
	var bdur = 64*SampleDur.ir;
	var ramp = bdur;
	var maxt = 10;
	var ins = SoundIn.ar([in]);
	//detect onsets
	var chain = FFT(LocalBuf(256), ins);
    var ons = Onsets.kr(chain, 0.3, \complex, mingap:100);
	// var lastons = Latch.kr(Delay1.kr(ons), ons);
	var tgl = ToggleFF.kr(ons);
	var route = [tgl, 1-tgl];
	var dts = Sweep.ar(ons*route); // time since last two onsets
	var del = Mix(fs.collect{ |f|
		var r = f/Sanitize.ar(ZeroCrossing.ar(ins)).lag(0.005);
		var dt =  Phasor.ar(ons, SampleDur.ir*(1-r), dts[0], dts[1], dts[0]);
		var phase = Sanitize.ar(dt - dts[0] / (dts[1]-dts[0]));
		var ramp = 1 - (phase * 2 - 1).abs;
		ramp = (ramp*100).clip(0,1);
		DelayC.ar(ins, maxt, dt)*ramp;
	});
	var env = Amplitude.ar(ins) / (Amplitude.ar(del)+1e-2);
	del = del * env;
	// del!2
	Mix(del)!2
};
Ndef(\left, {def.(6, [110,165])}).play;
Ndef(\right, {def.(7, [55,88])}).play;
)


(
// var rates = [1.005, 1.997, 0.5];
// var rates = [2];
var rates = [1.997, 2.002];
// var rates = [2,1.997,1.003];
// var rates = [1/2,2];
// var rates = [0.5pi, 0.5];
// var rates = [2,4,8];
Ndef(\double_feedback, {
	var bdur = 64*SampleDur.ir;
	var ramp = bdur;
	var maxt = 10;
	var in = SoundIn.ar([0]);
	//detect onsets
	var chain = FFT(LocalBuf(256), in);
    var ons = Onsets.kr(chain, 0.3, \complex, mingap:100);
	// var lastons = Latch.kr(Delay1.kr(ons), ons);
	var tgl = ToggleFF.kr(ons);
	var route = [tgl, 1-tgl];
	var dts = Sweep.ar(ons*route); // time since last two onsets
	var src = in + Ndef.ar(\double_feedback)[0] + Ndef.ar(\half_feedback)[0];
	var del = Mix(rates.collect{ |r|
		var dt =  Phasor.ar(ons, SampleDur.ir*(1-r), dts[0], dts[1], dts[0]);
		var phase = Sanitize.ar(dt - dts[0] / (dts[1]-dts[0]));
		var ramp = 1 - (phase * 2 - 1).abs;
		ramp = (ramp*100).clip(0,1);
		DelayC.ar(src, maxt, dt)*ramp;
	});
	var env = Amplitude.ar(in) / (Amplitude.ar(del)+1e-2);//Slew.ar(K2A.ar(route), 1/ramp, 1/ramp);//.lag(0.001);
	del = del * env.pow(0.5);
	// del!2
	Mix(del)!2
}).play;
)

(
// var rates = [0.5];
var rates = [0.501,0.499];
// var rates = [1/2,1/4,1/8];
Ndef(\half_feedback, {
	var bdur = 64*SampleDur.ir;
	var ramp = bdur;
	var maxt = 10;
	var in = SoundIn.ar([0]);
	//detect onsets
	var chain = FFT(LocalBuf(256), in);
    var ons = Onsets.kr(chain, 0.3, \complex);
	// delay line jumps to present on onset
	var tgl = ToggleFF.kr(ons);
	var route = [tgl, 1-tgl];
	var dt = Sweep.ar(ons*route);
	var env = Slew.ar(K2A.ar(route), 1/ramp, 1/ramp);//.lag(0.001);
	var decay = Slew.ar(K2A.ar(1-route), SampleRate.ir, 1/maxt);
	var src = in + HPF.ar(Ndef.ar(\half_feedback)[0]*0.9/rates.size, 30);
	var del = Mix(rates.collect{ |r| DelayC.ar(src, maxt, dt*(1-r) + bdur)})*env*decay;
	del.sum!2
}).play;
)

// experiments with no-input mixer (stereo)
(
// var rates = [0.501,0.499,0.25];
// var rates = [0.251,0.249,0.997];
// var rates = [0.251,0.249,0.1257,0.1249];
// var rates = [0.99,0.88,0.77,0.66,0.55,0.44,0.22,0.11];
// var rates = [1/2,1/3,1/4,1/5,1/6,1/7,1/8];
var rates = [1/2,1/4,1/8,1/16,1/32,1/64];
~pitchdown = {
	arg in;
	var bdur = 64*SampleDur.ir;
	var ramp = bdur;
	var maxt = 30;
	//detect onsets
	var chain = FFT(LocalBuf(256), in);
    var ons = Onsets.kr(chain, 0.9, \complex);
	// var ons = Onsets.kr(chain, 0.5, \complex);
	// delay line jumps to present on onset
	var tgl = ToggleFF.kr(ons);
	var route = [tgl, 1-tgl];
	var dt = Sweep.ar(ons*route);
	var env = Slew.ar(K2A.ar(route), 1/ramp, 1/ramp);//.lag(0.001);
	var decay = Slew.ar(K2A.ar(1-route), SampleRate.ir, 1/maxt);
	var del = Mix(rates.collect{ |r| DelayC.ar(in, maxt, dt*(1-r) + bdur)}.flop)*env*decay;
	del
};
~getpitch = {
	arg x;
	// DC.ar(777);
	ZeroCrossing.ar(Integrator.ar(x, 0.99)).lag(5e-3);
	// (Integrator.ar(ZeroCrossing.ar(x), 0.75)%5000).lag(1e-3); //crazy style
	// K2A.ar(Median.kr(3, FluidPitch.kr(x, [\pitch], algorithm:0, windowSize:512, fftSize:1024, hopSize:64))).lag(5e-3)
};
Ndef(\tracking_notch, {
	// var in = SoundIn.ar([0])!2;
	var in = SoundIn.ar([6,7]);
	var env, out, am, f0, f1, shift;
	//detect pitch
	var pitch = ~getpitch.(in);
	var proc = in;
	proc = Notch.ar(proc, pitch, rq:1);
	// proc = proc - DelayC.ar(proc,delaytime:Sanitize.ar(1/pitch).lag(5e-3));
	// proc = CombC.ar(proc, delaytime:Sanitize.ar(1/pitch).lag(5e-3), decaytime:-inf);
	env = Amplitude.ar(in) / (Amplitude.ar(proc)+1e-2);
	out = proc*env;
	am = [1+out[0]*out[1], 1+out[1]*out[0]];
	// var f0 = ZeroCrossing.ar(am).lag(5e-3);
	f0 = ~getpitch.(am);
	f1 = f0/16;
	// f1 = f0/8;
	// f1 = 77*4;
	// pitch.poll;
	shift = FreqShift.ar(am, f1-f0);
	out = shift.collect(~pitchdown).flatten;
	// out = Splay.ar([shift[0]]++shift.collect(~pitchdown).flatten++[shift[1]]);
	// out = Splay.ar(out);
	// out = Splay.ar([out[0], shift[0]]++shift.collect(~pitchdown).flatten++[shift[1], out[1]]);
	out = Mix(PanAz.ar(2, out, Integrator.ar([1,-1]*Amplitude.ar(out).lag(1e-2)/1e5)));
	Limiter.ar(out)
}).play;
)


// with separate pitch tracker
(
// var rates = [0.501,0.499,0.25];
var rates = [0.251,0.249,0.997];
~pitchdown = {
	arg in;
	var bdur = 64*SampleDur.ir;
	var ramp = bdur;
	var maxt = 10;
	//detect onsets
	var chain = FFT(LocalBuf(256), in);
    var ons = Onsets.kr(chain, 0.8, \complex);
	// var ons = Onsets.kr(chain, 0.5, \complex);
	// delay line jumps to present on onset
	var tgl = ToggleFF.kr(ons);
	var route = [tgl, 1-tgl];
	var dt = Sweep.ar(ons*route);
	var env = Slew.ar(K2A.ar(route), 1/ramp, 1/ramp);//.lag(0.001);
	var decay = Slew.ar(K2A.ar(1-route), SampleRate.ir, 1/maxt);
	var del = Mix(rates.collect{ |r| DelayC.ar(in, maxt, dt*(1-r) + bdur)})*env*decay;
	del
};
~getpitch = {
	arg x;
	// DC.ar(777);
	ZeroCrossing.ar(Integrator.ar(x, 0.99)).lag(5e-3);
	// (Integrator.ar(ZeroCrossing.ar(x), 0.75)%5000).lag(1e-3); //crazy style
	// K2A.ar(Median.kr(3, FluidPitch.kr(x, [\pitch], algorithm:0, windowSize:512, fftSize:1024, hopSize:64))).lag(5e-3)
};
Ndef(\tracking_notch, {
	var flute = SoundIn.ar([0]);
	var in = SoundIn.ar([6,7]);
	var env, out, am, f0, f1, shift;
	//detect pitch
	var pitch = ~getpitch.(in);
	var proc = in;
	proc = Notch.ar(proc, pitch, rq:1);
	// proc = proc - DelayC.ar(proc,delaytime:Sanitize.ar(1/pitch).lag(5e-3));
	// proc = CombC.ar(proc, delaytime:Sanitize.ar(1/pitch).lag(5e-3), decaytime:-inf);
	env = Amplitude.ar(in) / (Amplitude.ar(proc)+1e-2);
	out = proc*env;
	am = [1+out[0]*out[1], 1+out[1]*out[0]];
	// var f0 = ZeroCrossing.ar(am).lag(5e-3);
	f0 = ~getpitch.(am);
	f1 = ~getpitch.(flute);
	// f1 = f0/16;
	// f1 = f0/8;
	// f1 = 77*4;
	// pitch.poll;
	shift = FreqShift.ar(am, f1-f0);
	out = Splay.ar(~pitchdown.(flute).flatten++shift.collect(~pitchdown).flatten++[shift]);
	// out = Splay.ar([out[0], shift[0]]++shift.collect(~pitchdown).flatten++[shift[1], out[1]]);
	Limiter.ar(out)
}).play;
)






