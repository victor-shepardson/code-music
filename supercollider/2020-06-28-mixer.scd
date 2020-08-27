(
s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.options.numInputBusChannels = 8;
s.options.numOutputBusChannels = 8;

s.boot
)

s.queryAllNodes


(
p = ProxySpace.push(s);
MIDIIn.connectAll;
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

f[\sinc] = { |phi| var zero = (phi.abs<1e-8); phi.sin+zero/(phi+zero)};

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
)

(
var notes_held=0, pitch_voices=(-1)!12, vel_voices=(0)!12;
p.clear;
~in.ar(2);
~preout.ar(8);
~out.ar(8);
// ~aux.ar(2);
~out.play;
// ~aux.play(2);

~pitches.kr(12);
~pitches = { \notes.kr((-1)!12)}; //default value is crucial
// ~pitches.set(\notes, [30, 37, 44, 51, 70, 77, 84, 91]);
~velocities.ar(12);
~velocities = { T2A.ar(\vels.tr((0)!12))}; //default value is crucial

//keys
MIDIdef.noteOn(\set_note, { arg val, num, chan, src;
    switch (chan,
        0, { //keys
            // if no notes held, silence all voices
            if(notes_held==0, {pitch_voices.fill(-1); vel_voices.fill(0)});

            // set next voice
            pitch_voices[notes_held] = num;
            pitch_voices.postln;
            vel_voices[notes_held] = val;
            vel_voices.postln;

            ~pitches.set(\notes, pitch_voices);
            ~velocities.set(\vels, vel_voices); // this resets every note...

            notes_held = notes_held+1;

        },
        1,{ //pads

    })
},nil,nil);

MIDIdef.noteOff(\unset_note, { arg val, num, chan, src;
    notes_held = notes_held-1;
    // n[num].set(\vel, 0)
},nil,0);

);

(

// ~in = {SoundIn.ar([0,1])};
~in = {SoundIn.ar([2,3])};
// ~in = {SinOsc.ar([220, 440])};

~a = {Amplitude.ar(~in.ar)};

// ~f = {Tartini.kr(~in.ar)[0]};
~f = {ZeroCrossing.ar(~in.ar)};

~stop1 = {BBandStop.ar(~in.ar, ~f.kr.max(20), 2)};
~f1 = {ZeroCrossing.ar(~stop1.ar)};
~stop2 = {BBandStop.ar(~stop1.ar, ~f1.kr.max(20), 2)};
~f2 = {ZeroCrossing.ar(~stop2.ar)};

~ml = {MFCC.kr(FFT(LocalBuf(2048), ~in.ar[0]))-0.25};
~mr = {MFCC.kr(FFT(LocalBuf(2048), ~in.ar[1]))-0.25};
);

(

~tones_left = {Splay.ar(
    ~pitches.kr[(0..2).reverse*2 ++ ((0..2)*2+1)].collect({ arg pitch, i;
        var env = (pitch >= 0);
        var freq = pitch.midicps;
        FreqShift.ar(~in.ar[0], freq-~f.ar[0])*env
    })
)};

~tones_right = {Splay.ar(
    ~pitches.kr[(0..2).reverse*2 ++ ((0..2)*2+1)].collect({ arg pitch, i;
        var env = (pitch >= 0);
        var freq = pitch.midicps;
        FreqShift.ar(~in.ar[1], freq-~f.ar[1])*env
    })
)};

~plucks = {var
    k = 12,
    hyst = 0.1,
    dt = 8,
    mrc = ~mr.kr-Lag.kr(~mr.kr, dt)-hyst,
    mlc = ~ml.kr-Lag.kr(~ml.kr, dt)-hyst,
    pl = 1/((1..k)*(~pitches.kr[0]+mrc[12]+hyst).midicps),
    pr = 1/((1..k)*(~pitches.kr[1]+mlc[12]+hyst).midicps);
    Splay.ar(
        Pluck.ar(~in.ar[0], mrc[0..k-1], 1, pl, -0.95).reverse
        ++Pluck.ar(~in.ar[1], mlc[0..k-1], 1, pr, -0.95)
    )
};

~synth = {var
    // TODO: selector for 36 modes (each pair of 6 frequencies)
    silent = 1 - (~a.kr**2 * 100).distort,
    zf = ~f.kr, //[~f1.kr[0], ~f.kr[1]]
    r1 = zf[0] / ~pitches.kr.midicps + 1,
    r2 = zf[0] / LinSelectX.kr(silent[1], [zf[1], zf[0]]);
    Splay.ar(
        f[\stretch].(~pitches.kr.midicps, r2, f[\sinccos], r1/(r2 + 1 / 2))
        * (~pitches.kr>0) * (Decay2.ar((~velocities.ar/127)**2, 0.003, 10))
    ) * ArrayMax.ar(~a.ar)[0]
};
// ~tones = {0}
// ~plucks = {0}

~preout = {~tones_left.ar ++ ~tones_right.ar ++ ~plucks.ar ++ ~synth.ar};

~fx = ~preout; //{f[\wiggle].(~preout.ar, dry: 0, amt: 0.00003, rate: 5)};

~verb = {f[\wiggle].(GVerb.ar(Mix.new(~preout.ar),
    roomsize:50, revtime:5, damping:0.4, spread:0.9,
    earlyreflevel: 0.0, drylevel: 0
    ), dry: 0.3, amt: 0.002, rate: 1/3)};


~out = {0.95*Limiter.ar(0.2*LeakDC.ar(~verb.ar*0.00+~fx.ar))};

)

(
d.free;
d = {Poll(Impulse.kr(5), ~ml.kr[0], \mfcc)}.play
)

(
d.free;
d = {Poll(Impulse.kr(5), ~pitches.kr[0], \pitch)}.play
)

(
d.free;
d = {Poll(Impulse.kr(5), ~velocities.kr[0], \velocity)}.play
)


(
d.free;
d = {Poll(Impulse.kr(5), ~f1.kr, \f)}.play(s)
)

[1,2,3,4,5,6,7,8,9,10,11,12]

~in.scope
~env.scope
~out.scope
~aux.scope
~i.scope

{Decay.ar(~velocities.ar/128, 1)}.scope

~f1.scope

s.record(bus:~out.bus, numChannels:8);
s.stopRecording;

(
p.clear;
s.quit;
MIDIdef.freeAll;
)