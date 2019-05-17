(
s.options.memSize = 65536*8;
s.options.numAudioBusChannels = 512;
s.options.numInputBusChannels = 2;
s.options.numOutputBusChannels = 4;
s.options.numWireBufs = 1024;

s.boot;
MIDIIn.connectAll;
)

s.quit

(
p = ProxySpace.push(s);
f = Environment.new;
)

// ~proxy.set(\param, value)
// ~proxy.xset(\param, value)
// ~proxy.map(\param, ~controlproxy)
// ~proxy.xmap(\param, ~controlproxy)

(
p.clear;
// ~in.ar(2);
~preout.ar(2);
~out.ar(2);
// ~aux.ar(2);
~out.play;
// ~aux.play(2);

~out = {0.95*Limiter.ar(LeakDC.ar(1/4*~preout.ar))};
)

(
f[\sincextremum] = { |n| var
    q = n+0.5*pi;
    q - (1/q) - (q**(-3)*2/3)
};

// f[\sinc] = { |phi| phi.sin / phi.abs.max(1e-15) * (phi>=0 *2 -1)};
f[\sinc] = { |phi| (phi.abs>1e-15).if(phi.sin/phi, 1)};

f[\sincosc] = { |freq, band, mul=1, add=0, cutoff=24000|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min(cutoff/freq).floor,
	scale = f[\sincextremum].(band_);
    f[\sinc].(phi*scale)*mul+add
};

f[\sincosci] = {|freq, band, mul=1, add=0, cutoff=24000|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor),
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil);
    m*f[\sinc].(phi*scale1)+(1-m*f[\sinc].(phi*scale0))*mul+add
};

f[\amvoice] = {|freq, env|
    // f[\sincosc].(freq,4,1/2,1/2)**4*env;
    Saw.ar(freq, 1/2, 1/2)**3*env
};

f[\voice] = {|freq, env|
    /*BLowPass4.ar(
        Saw.ar(freq, -1),
        ((freq*16)*env+freq/2).clip(20,20000),
        0.25
    )*env*/
    f[\sincosci].(freq, env*7+1)*env
    //SinOsc.ar(freq, mul:env)
};

//exponentially spaced shepard tone
f[\tone] = {|master_phase, voices, root, synth, base=2|
    Mix.fill(voices, {|i| var
        phase = (i/voices+master_phase).wrap(0,1),
        env = 1-(phase*2pi).cos/2,
        pitch = base**(phase*voices)*root;
        synth.(pitch, env)/voices.sqrt
})};

// Array.fill(3, {|i| 2**i*[1,2,3]}).flatten.asSet.asArray.sort.reverse.at(0)
//chord-exponentially spaced shepard tone
f[\ctone] = {|master_phase, octaves, root, synth, chord=#[0]| var
    intervals = Array.fill(octaves, {|i| i+chord}).flatten.asSet.asArray.sort,
    voices = intervals.size,
    top = intervals.reverse.at(0).ceil;
    Mix.fill(voices, {|i| var
        phase = (intervals.at(i)/top+master_phase).wrap(0,1),
        env = 1-(phase*2pi).cos/2,
        pitch = 2**(phase*top)*root;
        synth.(pitch, env)/voices.sqrt
})};

//linearly spaced shepard tone (oscillates between harmonic/inharmonic)
f[\ltone] = {|master_phase, voices, root, synth|
    Mix.fill(voices, {|i| var
        phase = (i/voices+master_phase).wrap(0,1),
        env = 1-(phase*2pi).cos/2,
        pitch = (phase*voices+1)*root;
        synth.(pitch, env)/voices.sqrt
})};

//generic shepard tone which just supplies phase and envelope to each synth voice
f[\gtone] = {|master_phase, voices, synth|
    Mix.fill(voices, {|i| var
        phase = (i/voices+master_phase).wrap(0,1),
        env = 1-(phase*2pi).cos/2;
        synth.(phase*voices, env)/voices.sqrt
})};
)

//shepard tone interference drone
(
~voices = 8;
~ctlenv = {EnvGen.ar(Env.adsr(0, 480, 0, 0))};
~root = 55;//{2**(3*~ctlenv)*55};//{2**SinOsc.ar(8, add:1, mul:1/8)*32};
~amroot = 1;
~period = {2**(-8*~ctlenv)*240};//240;
~preout = { var
    n = ~voices.source,
    phase = LFSaw.ar(1/n/~period, 0, 1/2, 1/2),
    amphase = (phase*16).wrap(0,1);
    Splay.ar([
        //f[\tone].(amphase, n, ~amroot, f[\amvoice])*f[\tone].(1-phase, n, ~root, f[\voice]),
        //f[\tone].(1-amphase, n, ~amroot, f[\amvoice])*f[\tone].(phase, n, ~root, f[\voice])
        f[\ltone].(1-phase, n, ~root, { |f,a| SinOsc.ar(f)*a}),
        f[\sincosc].(~root, n),
        f[\ltone].(phase, n, ~root, { |f,a| SinOsc.ar(f)*a})
    ]).sin
};
)

~preout = {};

//sinc drone
(
~preout = { arg
    root = 48,
    period = 8,
    spread = 1/period;
    Splay.ar([
        f[\sincosci].(root-spread, 2**SinOsc.ar(1/4/period, -0.5pi, 4, 3)+1),
        f[\sincosci].(root, 2**SinOsc.ar(1/5/period, -0.5pi, 4, 3)+1),
        f[\sincosci].(root+spread, 2**SinOsc.ar(1/3/period, -0.5pi, 4, 3)+1)
    ]*0.5pi).sin};
)

(
MIDIdef.cc(\cc1, { arg x; var
    y = 2**(0-x/10)*128;
    ~preout.set(\period, y);
    y.postln;
}, 1);
MIDIdef.cc(\cc2, { arg x; var
    y = 2**(0-x/10)*16;
    ~preout.set(\spread, y);
    y.postln;
}, 2);

MIDIdef.noteOn(\noteon, { arg v, p; var
    freq = p.midicps;
    ~preout.set(\root, freq);
    freq.postln
})
)

(
~preout = { arg
    root = 48,
    period = 64,
    spread = 1/4,//period,
    mul = 4, add = 3;
    (Splay.ar(SplayAz.ar(4, [
        f[\sincosci].(root+(spread*2), 2**SinOsc.ar(2/7/period, -0.5pi, mul, add)+1),
        f[\sincosci].(root, 2**SinOsc.ar(1/5/period, -0.5pi, mul, add)+1),
        f[\sincosci].(root-spread, 2**SinOsc.ar(1/4/period, -0.5pi, mul, add)+1),
        f[\sincosci].(root, 2**SinOsc.ar(1/3/period, -0.5pi, mul, add)+1),
        f[\sincosci].(root+spread, 2**SinOsc.ar(2/11/period, -0.5pi, mul, add)+1),
        f[\sincosci].(root, 2**SinOsc.ar(3/13/period, -0.5pi, mul, add)+1),
        f[\sincosci].(root-(spread*2), 2**SinOsc.ar(4/17/period, -0.5pi, mul, add)+1),
        f[\sincosci].(root, 2**SinOsc.ar(5/19/period, -0.5pi, mul, add)+1),
    ]*pi).sin)*0.5pi).sin};
)

//stacked sinc drone
(
~preout = {Mix.fill(6, { |i| var
    inc = 2**i,
    beat_period = [60, 40, 15, 20, 24, 30].at(i)/16,///(i+1)*0.94/4,
    interval = [1, 16/7, 8/5, 5/2, 4/3, 6].at(i),
    // interval = [1, 9/4, 3, 16/3, 8].at(i),
    // interval = [1, 16/9, 8/3, 128/27, 6, 9].at(i),
    root = interval*35,//*55
    period = 4,//8,//inc*(i+1)*8,
    pp = i*2+16,
    env = SinOsc.kr(1/(1-EnvGen.ar(Env.perc(0, 600, -3))*300+1), 2pi*i/5, 1/2, 1/2)**3,//SinOsc.kr(1/300, 2pi*i/5, 1/2, 1/2)**3,
    dry = EnvGate.new * (
        0.5pi*env
        *Splay.ar([
            f[\sincosci].(root-(1/beat_period), 2**SinOsc.ar(1/period/pp.nthPrime, -pi/2, 4, 3)+1),
            f[\sincosci].(root, 2**SinOsc.ar(1/period/(pp+2).nthPrime, -pi/2, 4, 3)+1),
            f[\sincosci].(root+(1/beat_period), 2**SinOsc.ar(1/period/(pp+1).nthPrime, -pi/2, 4, 3)+1)
        ])
    ),
    shaped = dry.sin,
    (
        GVerb.ar(
            HPF.ar(Mix.new(shaped), freq:root*2),
            roomsize:i*10+30, revtime:i+0.5, damping:0.7, spread:i*20+10,
            earlyreflevel: 0.0,
            drylevel:0//mul:0.05//(1-(1/inc))/2
        )
        *(0.02*i+0.02)
        +Splay.ar(shaped/(interval**2), spread:2/(i+2))
    )//*(i>=5).asInteger
})};
)

//stacked sinc drone 2
(
~preout = {var
    root = 30,
    sig = Mix.fill(6, { |i| var
        inc = 2**i,
        beat_period = 2**(0-i)/2,//1/(1+i)/3,//[60, 40, 15, 20, 24, 30].at(i)/16,
        interval = 8*[1, 4/3, 8/5, 8/7, 16/11, 16/13].at(i),//[1, 5, 4, 3, 2, 6].at(i),//[1, 16/7, 8/5, 5/2, 4/3, 6].at(i),
        fund = interval*root,
        period = 4,
        pp = i*2+16,
        env = SinOsc.kr(1/(1-EnvGen.ar(Env.perc(0, 600, -3))*300+1), 2pi*i/5, 1/2, 1/2)**3,
        dry = EnvGate.new * (
            Splay.ar([
                f[\sincosci].(fund-(1/beat_period), 2**SinOsc.ar(1/period/pp.nthPrime, -pi/2, 3, 2)+1),
                f[\sincosci].(fund, 2**SinOsc.ar(1/period/(pp+2).nthPrime, -pi/2, 3, 2)+1),
                f[\sincosci].(fund+(1/beat_period), 2**SinOsc.ar(1/period/(pp+1).nthPrime, -pi/2, 3, 2)+1)
            ]) * env * 0.5pi
        ).sin;
        Splay.ar(dry, spread:2/(i+2))
    });
    // sig.sin
    0
    // +((sig - 2) * (sig > 2))
    +((sig - 1) * (sig > 1))
    // +((sig - 0) * (sig < 0))
    // -sig.sin
};
)

//shepard timbre
(
~preout = { var
    n = 2,
    period = 2,
    pitch = 55,
    partials = 32,
    phase = LFSaw.ar(1/n/period, 0, 1/2, 1/2);
    Splay.ar([
        f[\gtone].(phase, n, { |phase, env| var
            partial = phase/n*partials+1;
            HPF.ar(f[\sincosci].(pitch, partial)*env, pitch*partial/2)
        })
    ])
};
)

//shepard chord
(
~preout = { var
    octaves = 2,
    chord = [1, 16/9, 8/3, 128/27, 6, 9].log2,//[1, 3/2, 8/3].log2,
    root = 55,
    period = 8,
    phase = 1-LFSaw.ar(1/octaves/period, 0, 1/2, 1/2);
    Splay.ar([
        f[\ctone].(phase, octaves, root, f[\voice], chord)
    ]).sin
};
)

//sinc notes
(
SynthDef(\sound, { arg out,
    freq = 440,
    dur = 0.3,
    amp = 0.2;
    var
    env = EnvGen.ar(Env.perc(0.0005, dur, curve:0), doneAction:2);
    Out.ar(out,
        f[\sincosci].(env**(amp*5+6)*8+1*freq, (0.5-(0.5-env).abs*2)**2*8+(5*amp), env)
        .dup(2)*amp)
}).add;
MIDIdef.noteOn(\noteon, { arg v, p; var
    freq = p.midicps,
    amp = v/128*0.2+0.02,
    dur = 2**(v/64)*0.07;
    // ~preout.add(\sound).set(\freq, freq);
    Synth(\sound, [\freq, freq, \amp, amp, \dur, dur])
})
)


s.quit
s.record("~/record/excerpt.wav", 0);
s.stopRecording;
