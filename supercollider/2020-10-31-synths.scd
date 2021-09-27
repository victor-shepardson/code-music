(
s.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
s.options.memSize = 8192 * 64; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 4; // set this to your hardware input channel size, if necessary
s.boot;
)

(
f = Environment.new;

f[\wiggle] = { |in, amt=0.001, rate=3, rates=#[0.01, 0.1, 1], shape=1, dry=0|
	var waveform = {|r, m| var freq = r*(2**m);
		SinOsc.kr(freq) + LFNoise1.kr(freq*2) / 2;
	},
	wave = 0;
	for (0, rates.size-1, { |i|
		wave = waveform.(rate*rates[i], wave*shape);
	});
	dry*in + DelayC.ar(in, 3*amt, (wave+1)*amt/2+(SampleDur.ir*4))
};


f[\sincextremum] = { |n|
    var q = n+0.5*pi;
    q - (1/q) - (q.pow(-3)*2/3)
};

f[\sinc] = { |phi| var zero = (phi.abs<1e-8); phi.sin+zero/(phi+zero)};


f[\sincosc] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, iphase=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:iphase),
    band_ = band.min(cutoff/freq).max(0).floor+1,
	scale = f[\sincextremum].(band_);
    f[\sinc].(phi*scale+pm)-(0.5pi/scale*fixdc)*mul*EnvGate.new+add
};

f[\sincosci] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor).max(0)+1,
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil),
    osc0 = f[\sinc].(phi*scale0+pm)-(0.5pi/scale0*fixdc),
    osc1 = f[\sinc].(phi*scale1+pm)-(0.5pi/scale1*fixdc);

    m*osc1+(1-m*osc0)*mul*EnvGate.new+add
};

f[\poly] = { |x, s_i, v_f|
    var x_ = x.abs;
    s_i-v_f/2*x_ - (s_i-v_f*3/2)*x_ + s_i*x_ * x.sign
};
f[\sincosci2] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor).max(0)+1,
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil),
    scale = f[\sincextremum].(band_),
    x0 = f[\poly].(phi, scale, scale0),
    x1 = f[\poly].(phi, scale, scale1),
    osc0 = f[\sinc].(x0+pm)-(0.5pi/scale0*fixdc),
    osc1 = f[\sinc].(x1+pm)-(0.5pi/scale1*fixdc);

    m*osc1+(1-m*osc0)*mul*EnvGate.new+add
};


f[\sinccos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    sinc = f[\sinc].(ratio*phi*pi),
    cos_env = (pi*phi).cos +1 /2;
    sinc * cos_env
};

f[\coscos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    cos_wave = (ratio*phi*pi).cos,
    cos_env = (pi*phi).cos +1 /2;
    cos_wave * cos_env
};

f[\sinsincos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    fold_wave = ((phi*pi).sin*ratio*pi).sin,
    cos_env = (pi*phi).cos +1 /2;
    fold_wave * cos_env
};

f[\sinsigcos] = {
    arg freq, ratio;
    var phi = LFSaw.ar(freq, iphase:0),
    squash_wave = ((phi*pi).sin*(ratio**2)/2).distort,
    cos_env = (pi*phi).cos +1 /2;
    squash_wave * cos_env
};

f[\sinsinsigcos] = {
    arg freq, ratio, ratio2;
    var phi = LFSaw.ar(freq, iphase:0),
    fold_wave = ((phi*pi).sin*ratio*pi).sin,
    squash_wave = (fold_wave*(ratio2**2)).distort,
    cos_env = (pi*phi).cos +1 /2;
    squash_wave * cos_env
};

f[\stretch] = {
    arg freq, ratio, osc ...oscargs;
    FreqShift.ar(osc.(freq*ratio, *oscargs), 0-(ratio -1 *freq))
};

f[\blip] = {
    arg rate, freq;
    var phi = LFSaw.ar(rate, iphase:0),
    cos_env = (pi*phi).cos +1 /2,
    cos_freq = 1 -freq.sign /2 *freq.abs + (cos_env *freq),
    wave = SinOsc.ar(cos_freq);
    wave * cos_env
};

f[\chirp] = {
    arg rate, freq;
    var phi = LFSaw.ar(rate, iphase:0),
    cos_env = (pi*phi).cos +1 /2,
    lin_freq = 1 -freq.sign /2 *freq.abs +(phi +1 /2 *freq),
    wave = SinOsc.ar(lin_freq);
    wave * cos_env
};

t.free;
t = {Splay.ar((
    f[\chirp].(1/[2,-3,-4,-5,6,-7] +1, 550) * f[\blip].(8/[11,13,17], [220,330,440,550,660,770]/55)
)*pi).sin}.play
// t = {Splay.ar(f[\chirp].([1]/2, -550))}.play
// t = {Splay.ar(f[\blip].([1], -330))}.play
)

t.free

// t = {f[\sinccos].(110,1)}.play

// t = {f[\sinccos].(54.5,SinOsc.kr(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54, (5/3), f[\sinccos], SinOsc.ar(27/3) +1 /2 **2 * 16 +1)}.play;

// t = {f[\stretch].(54, (1), f[\sinccos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54, (1), f[\coscos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54, (1), f[\sinsincos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

// t = {f[\stretch].(54*2, (1), f[\sinsigcos], SinOsc.ar(1/8) +1 /2 **2 * 32)}.play;

/*t = {Splay.ar([
f[\stretch].(54*2, (3/4), f[\sinsinsigcos],
    SinOsc.ar(1/32) +1 /2 **2 * 4 + 0.25,
    SinOsc.ar(1/11) +1 /2 **2 * 1 + 0.5
),
f[\stretch].(54*4, (1/4), f[\sinsinsigcos],
    SinOsc.ar(1/45) +1 /2 **2 * 2 + 0.25,
    SinOsc.ar(1/7) +1 /2 **2 * 1 + 0.5
),
f[\stretch].(54*3, (2/4), f[\sinsinsigcos],
    SinOsc.ar(1/65) +1 /2 **2 * 3 + 0.25,
    SinOsc.ar(1/13) +1 /2 **2 * 1 + 0.5
)
])}.play;*/

)


thisProcess.platform.recordingsDir
s.record
s.stopRecording

s.quit