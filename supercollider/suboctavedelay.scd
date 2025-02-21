(
s.options.numInputBusChannels = 8;
s.options.hardwareBufferSize = 64;
s.options.blockSize = 64;
s.options.inDevice = "K-Mix";
s.options.outDevice = "K-Mix";
s.options.numWireBufs = 512;
s.options.memSize = 8192*32;
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
	var dt = Sweep.ar(ons*route); // time since last two onsets
	var del = Mix(rates.collect{ |r|
		DelayC.ar(in, maxt, Phasor.ar(ons, SampleDur.ir*(1-r), dt[0], dt[1], dt.max))
	});
	var env = Amplitude.ar(in) / (Amplitude.ar(del)+1e-2);//Slew.ar(K2A.ar(route), 1/ramp, 1/ramp);//.lag(0.001);
	del = del * env;
	// del!2
	Mix(del)!2
}).play;
)