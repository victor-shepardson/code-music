(
s.options.numInputBusChannels = 8;
s.options.numOutputBusChannels = 8;
s.options.sampleRate = 96000;
s.options.memSize = 65536;
s.boot;
)

s.quit

(
var deviceName = "MPKmini2";

MIDIClient.initialized.not.if{MIDIClient.init};
MIDIIn.connectAll;
~device = MIDIClient.sources.detect{
	|e| e.device.containsi(deviceName)
}.uid;

MIDIdef.noteOn(\keys, {arg val, num, chan, src;
	num.midicps.postln;
}, srcID:~device, chan:0).permanent_(true);

~pads_held = Set[];
MIDIdef.noteOn(\pads, {arg val, num, chan, src;
	~pads_held.add(num-32).postln;
}, srcID:~device, chan:1).permanent_(true);
MIDIdef.noteOff(\pads_off, {arg val, num, chan, src;
	~pads_held.remove(num-32).postln;
}, srcID:~device, chan:1).permanent_(true);

~set_by_pads = {arg ...args;
	var synth_idxs = (~pads_held.size==0).if{(0..7)}{~pads_held};
	synth_idxs.postln.do{arg idx; ~synths[idx].set(*args)};
};

MIDIdef.cc(\knobs, {arg val, num, chan, src;
	switch (num)
	{1} {~set_by_pads.(\lu.postln, 2.pow(val/8-7).postln)}
	{2} {~set_by_pads.(\ld.postln, 2.pow(val/8-7).postln)}
	{3} {~set_by_pads.(\lz.postln, 2.pow(val/8-12).postln)}
	{4} {~set_by_pads.(\zlp.postln, (2.pow(val/13.5)*30).postln)}
	{5} {~set_by_pads.(\gain.postln, (val/127).pow(4).postln)}
	{6} {~set_by_pads.(\rate.postln, ((val/127).pow(4)*30).postln)}
	{7} {~set_by_pads.(\mixlfo.postln, (val/127).postln)}
	{8} {~set_by_pads.(\alv.postln, (val/127).pow(4).postln)}
}, srcID:~device).permanent_(true);

)

(

~detect = { arg sig;
	var xing = Trig1.ar(sig, SampleDur.ir);
	var bands = BPF.ar(sig, [50,100,200,400,800,1600,3200,6400,12800]);
	// var amp = Amplitude.ar(bands);
	var quad = Hilbert.ar(bands).flop;
	var amp = quad[0]*quad[0]+(quad[1]*quad[1]);
	var feat = Mix.ar(HPZ1.ar(amp).abs.lag(0.01));
	var feat_center = feat - feat.lag2(5);
	var poi = Trig1.ar(feat_center*xing - 0.0001, 0.1);
	// SendTrig.ar(poi);
	// feat_center.poll(10);
	poi;
};

~rhythmize = { arg sig, tr;
	var poi = ~detect.(sig);
	var delay_to_poi = Sweep.ar(poi, 1);
	var del = Latch.ar(delay_to_poi, tr);
	var dmax = 30;
	// delay_to_poi.poll(2.1);
	// del.poll(2);
	DelayN.ar(sig, dmax, del)*(dmax-del).max(0)/dmax;
};

SynthDef(\analyzer, {
	var inputs = [Mix.ar(In.ar([0,1])), Mix.ar(SoundIn.ar([4,5]))];
	var poi = ~detect.(inputs);
	var f0 = ZeroCrossing.ar(inputs);
	var amp = Amplitude.ar(inputs);
	poi = DelayN.ar(poi, 0.1, 0.01);
	// SendReply.ar(poi, \analysis, [amp, f0].flop);
	SendReply.ar(poi[0], '/analysis', [amp[0], f0[0], DC.ar(0)]);
	SendReply.ar(poi[1], '/analysis', [amp[1], f0[1], DC.ar(1)]);
}).add;

SynthDef(\shift, {
	var rate = \rate.kr(0, 0.1);
	var tr = [Impulse.ar(rate), Impulse.ar(rate*\div.kr(1))];
	var gain = \gain.kr(0, 0.05);
	var fs = [\fl.kr(55), \fr.kr(110)].lag3ud(\lu.kr(0, 0.1), \ld.kr(0, 0.1));
	var sig = SoundIn.ar([6,7]);
	var f0 = ZeroCrossing.ar(LPF.ar(sig, \zlp.kr(12000, 0.1))).lag(\lz.kr(0.03, 0.1));
	// (fs-f0).poll;
	var pr,pl;
	f0 = Gate.ar(f0, Amplitude.ar(sig)>0.001);
	sig = FreqShift.ar(sig, fs-f0);
	// pl = sig[0];
	// pr = sig[1];
	// pl = ~rhythmize.(sig[0], tr[0]);
	// pr = ~rhythmize.(sig[1], tr[1]);
	pl = if(rate|==|0.0, sig[0], ~rhythmize.(sig[0], tr[0]));
	pr = if(rate|==|0.0, sig[1], ~rhythmize.(sig[1], tr[1]));
	Out.ar(0, Limiter.ar(HPF.ar([pl, pr], 20)*gain, \limit.kr(0.125, 0.3)))
}).add;

)

(
~synths = [Synth(\shift)];
~aux = Monitor.new;
~aux.play(fromIndex:0, fromNumChannels:2, toIndex:2, toNumChannels:2, addAction:\addToTail);

~s0 = ~synths[0];

~analyzer = Synth(\analyzer, addAction:'addToTail');
~s0.set(\limit, 0.25);
)

~noto.reset;
~gate = true;
~gate = false;

~s0.set(\div, 1.99)
~s0.set(\div, 3.03)
~s0.set(\div, 3/7)
~s0.set(\div, 8.04)
~s0.set(\div, 1.04)


~s0.set(\fl, 55, \fr, 55);
~s0.set(\fl, 110, \fr, 165);
~s0.set(\fl, 220, \fr, 330);
~s0.set(\fl, 550, \fr, 770);
~s0.set(\fl, 990, \fr, 880);



// ~analyzer.free
// ~aux = Monitor.new;
// ~aux.play(fromIndex:14, fromNumChannels:2, toIndex:0, toNumChannels:2, addAction:\addToTail);