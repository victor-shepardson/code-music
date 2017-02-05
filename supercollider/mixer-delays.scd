s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.boot
s.quit

s.queryAllNodes

p = ProxySpace.push(s);

// ~proxy.set(\param, value)
// ~proxy.xset(\param, value)
// ~proxy.map(\param, ~controlproxy)
// ~proxy.xmap(\param, ~controlproxy)

(
p.clear;
~in.ar(2);
~out.ar(2);
~aux.ar(2);
~out.play;
~aux.play(2);
// ~in.ar(2);

~in = {SoundIn.ar([0,1])};

//~synth = {SinOsc.ar(440)};

~dtime = 0.01;
~cutoff = 30;
~filt = {BLowPass4.ar(~in.ar, ~cutoff)};
~env = {0.5 + Limiter.ar(~filt.ar, 0.5)};
~del = {DelayC.ar(~in.ar, 1, ~env.ar.reverse**4*~dtime)};
~out = {Limiter.ar(~del.ar)};

// ~aux = ~out
// ~aux = {Limiter.ar(FreqShift.ar(~del.ar, 3))};
~aux = {Limiter.ar(FreqShift.ar(~in.ar, ~filt.ar.reverse*1))};
~aux = {Limiter.ar(FreqShift.ar(~in.ar, ~env.ar.reverse*10))};
// ~out = ~aux;
~out = ~in;

)

~in.scope
~env.scope
~out.scope
~aux.scope