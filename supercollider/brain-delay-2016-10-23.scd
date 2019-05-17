(
s.options.memSize = 2000000;
s.options.numAudioBusChannels = 512;
s.options.numOutputBusChannels = 4;
s.options.blockSize = 64;
s.boot
)
s.quit

s.queryAllNodes

p = ProxySpace.push(s);

// ~proxy.set(\param, value)
// ~proxy.xset(\param, value)
// ~proxy.map(\param, ~controlproxy)
// ~proxy.xmap(\param, ~controlproxy)

// l = {|x| 1/(1+exp(0-x))};

/*d = Buffer.cueSoundFile(s,"/home/victor/kaggle-python/audio/eeg_hourly_5pcs_44100/patient_1_interictal_hour_000.wav",0,2);*/
d = Buffer.cueSoundFile(s,"/home/victor/kaggle-python/audio/eeg_hourly_clean_44100_2pcs/patient_1_preictal_hour_004.wav",0,2);

(
{ var
	//moving variance
	moving_var = {|in, decayTime|
		var coef = 1-(0.5**(SampleDur.ir/decayTime));
		A2K.kr(Integrator.ar(coef*in*in, 1-coef))
		// BLowPass4.ar(in*in, 1/decayTime)
	},
	hjorth = {|in, decayTime|
		var diff = 4pi*HPZ1.ar(in),
		diff2 = 8pi*HPZ2.ar(in),
		v0 = moving_var.(in, decayTime),
		v1 = moving_var.(diff, decayTime),
		v2 = moving_var.(diff2, decayTime),
		eps = 0;//1e-15;
		[v0*(v1/(v0+eps.sqrt)).sqrt, v0*(v2*v0).sqrt/(v1+eps)]
	},
	multi_tap = {|in, return, dtimes, fb|
		DelayC.ar(in+(fb*return), 100, dtimes)
	},
	filt_shift = {|in, lo=20, hi=16000, amt=300|
		var filt = BHiPass.ar(BLowPass.ar(in, hi, 4),lo,2);
		FreqShift.ar(filt, amt*filt.rotate(1))
	},
	env = {|in, attack=0.03, decay=0.3, floor=0|
		Clip.ar(Decay2.ar(in.abs, attack, decay),floor,1)
	},
	adaptenv = {|in, attack=0.03, decay=0.05, decay2=3.0, floor=0.01|
		var running = env.(in, attack, decay2, floor).sqrt;
		Clip.ar(Decay2.ar(in.abs, attack, decay/running)/running,0,1)
	},
	hyst_cmp = {|in1, in2, amt = 1.5|
		var trig_up = in1/in2 > amt,
		trig_down = in2/in1 > amt;
		Latch.ar(trig_up-trig_down, (trig_up+trig_down)/2)
	},
	sl_delay = {|in, slew, dt_max, dt|
		var lim_dt = Slew.ar(dt, slew, slew);
		DelayC.ar(in, dt_max, lim_dt)
	},
	sl_xfade_delay = {|in, slew, dt_max, dt, ramp_time|
		var lim_dt = Slew.ar(dt, slew, slew),
		delta = (dt-lim_dt).abs,
		trig = delta>ramp_time,
		ff = ToggleFF.ar(trig),
		ramp = Slew.ar(ff, 1/ramp_time, 1/ramp_time),
		ramps = [ramp, 1-ramp],
		slew_rates = slew/(ramps+0.0001),
		lim_dts = Slew.ar(dt, slew_rates, slew_rates);
		Mix.ar(DelayC.ar([in, in], dt_max, lim_dts, ramps))
	},
	// rate < 1, attacks reset the delay time to zero
	dynsubdelay = {|in, return, rate=0.5, ramp_time=0.01|
		var dt_max = 100,
		trig = hyst_cmp.(Amplitude.ar(Mix.new(in.abs), 0.003, 0.1), Amplitude.ar(Mix.new(return.abs), 0.003, 0.1)),
		dt = Phasor.ar(trig, (1-rate)*SampleDur.ir, SampleDur.ir*4, dt_max, SampleDur.ir*4);
		sl_xfade_delay.(in, 1, dt_max, dt, ramp_time)
		// env = ((Sweep.ar(Changed.ar(dt, 0.01), 0.5/ramp_time)).min(1)*2-1).abs,
		// del_dt = DelayL.ar(dt, ramp_time, ramp_time);
		// env*DelayC.ar(in, dt_max, del_dt+ramp_time)
	},
	//rate > 1, at zero, reset delay time to last attack (alternatively, at time of last attack reset to previous?)
	dynsuperdelay = {|in, return, rate=3, ramp_time=0.005|
		var dt_max = 10,
		in_env = Amplitude.ar(Mix.new(in.abs), 0.003, 0.1),
		trig = hyst_cmp.(in_env, 0.01),
		time_since_trig = Phasor.ar(trig, SampleDur.ir, SampleDur.ir*4, dt_max, SampleDur.ir*4),
		dt = Phasor.ar(0, (1-rate)*SampleDur.ir, Delay1.ar(time_since_trig)+ramp_time, SampleDur.ir*4);
		sl_xfade_delay.(in, 8, dt_max, dt, ramp_time)
		// out_env = ((Sweep.ar(Changed.ar(dt, 0.01), 0.5/ramp_time)).min(1)*2-1).abs,
		// del_dt = DelayL.ar(dt, ramp_time, ramp_time);
		// out_env*DelayC.ar(in, dt_max, del_dt)
	},
	ratio = [5/4,1,2/3];//[1,3/2,4/3,5/4,6/5];

	p.clear;
	~d0.ar(3);
	~d1.ar(3);
	~d2.ar(3);
	~preout.ar(2);
	~out.ar(2);
	~out.play;
	~aux.ar(2);
	~aux.play(2);
	~env0.ar(3);
	~env1.ar(3);
	~env2.ar(3);

	~in = {SoundIn.ar([0,1])};
	// ~wav = {VDiskIn.ar(2,d,0.05,1)};
	// ~wav = {0.3*VDiskIn.ar(2,d,0.05*Mix.new(~env1.ar/3),1)};
	// ~wav2 = {BHiPass4.ar(~wav.ar, 30, 1)};
	// ~wav2 = {BLowPass4.ar(~wav.ar,30,1)*SinOsc.ar(1300)+BHiPass4.ar(~wav.ar, 30, 1)};
	// ~wav2 = {0.2*SinOsc.ar(~wav.ar*300+300)};
	// ~wav2 = {0.2*SinOsc.ar(2**(~wav.ar*4)*400)};

	// ~hjorth = {hjorth.(LeakDC.ar(Limiter.ar(~in.ar*32)), 0.03)};
	// ~hjorth.scope;
	// ~out = {Pan2.ar(~in.ar, (~hjorth.ar[0]-~hjorth.ar[1])**2*100)};

	~fb = 0.999;
	~dtime = (1/0.36/4);

	~din = ~in;

	// ~e0 = {LinXFade2.ar(~din.ar[0],~din.ar[1], [0.1, 0.5, 0.9])};
	// ~env0 = {adaptenv.(~e0.ar)};
	// ~d0 = {multi_tap.(~e0.ar, filt_shift.(~d0.ar,20,16000,300), ~dtime*1*ratio, ~fb*(1-~env0.ar))};
	// ~s0 = {Splay.ar(~d0.ar)};
	// ~e1 = {LinXFade2.ar(~s0.ar[0],~s0.ar[1], [0.1, 0.5, 0.9])};
	// ~env1 = {adaptenv.(~e1.ar)};
	// ~d1 = {multi_tap.(~din.ar+~e1.ar.reverse, filt_shift.(~d1.ar,20,16000,300), ~dtime*4*ratio, ~fb*(1-~env0.ar))};
	// ~s1 = {Splay.ar(~s1.ar)};
	// ~e2 = {LinXFade2.ar(~s1.ar[0],~s1.ar[1], [0.1, 0.5, 0.9])};
	// ~env2 = {adaptenv.(~e2.ar)};
	// ~d2 = {multi_tap.(~in.ar+~e2.ar.reverse, filt_shift.(~d2.ar,20,16000,300), ~dtime*16*ratio, ~fb*(1-~env0.ar))};

	// ~dhalf = {dynsubdelay.(~din.ar, ~dhalf.ar)};
	~ddouble = {dynsuperdelay.(~din.ar, ~ddouble.ar, 2)};
	// ~dfifth = {dynsuperdelay.(~in.ar, ~ddouble.ar, 1.5)};
	// ~dtriple = {dynsuperdelay.(~in.ar, ~dtriple.ar, 3)};

	~preout = ~in;//+~s0;
	// ~preout = ~in + ~ddouble;
	// ~preout = ~dhalf;
	// ~preout = ~in + ~dhalf + ~ddouble + ~dtriple;
	// ~preout = {~in.ar*0.7+Splay.ar(~d0.ar+~d1.ar+~d2.ar)+~wav2.ar};
	// ~preout = {~in.ar*0.7+Splay.ar(~d0.ar)+~wav2.ar};
	~out = {0.5*Limiter.ar(BHiPass4.ar(~preout.ar, 30, 1.5))};

	// ~out = ~in
	// ~aux = ~dfifth + ~dhalf;
	// ~aux = {0.75*~ddouble.ar.reverse + ~dhalf.ar.reverse};
	~aux = {~ddouble.ar.reverse};
	// ~aux = {filt_shift.(~ddouble.ar.reverse,20,16000,300)};
	// ~aux = {FreqShift.ar(Splay.ar(~d0.ar+~d1.ar), 0.3)};
	// ~aux = {Splay.ar(~d0.ar)};
	// ~aux = ~wav2

}.value
)

b = Buffer.alloc(s, 262144, 2);
b.write("sc/rec/brain-delay-6.wav".standardizePath, "wav", "int16", 0, 0, true);
~disk = {DiskOut.ar(b, ~out.ar)};
b.close;
b.free;

~in.scope
~env0.scope
~out.scope
~aux.scope