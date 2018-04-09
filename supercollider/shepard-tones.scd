(
s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.options.numInputBusChannels = 2;
s.options.numOutputBusChannels = 4;
s.options.numWireBufs = 1024;

s.boot
)

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

~out = {0.95*Limiter.ar(LeakDC.ar(4*~preout.ar))};
)

(
f[\sinc] = {|phi| phi.sin / phi.abs.max(1e-15) * (phi>0 *2 -1)};

f[\sincosc] = {|freq, band, mul=1, add=1|
    var phi = LFSaw.ar(freq),
	scale = (band+0.5)*1pi - (1/((band+0.5)*1pi));
    f[\sinc].(phi*scale)*mul+add
};

f[\sincosci] = {|freq, band, mul=1, add=1|
    var phi = LFSaw.ar(freq),
    m = band%1,
	scale0 = (band.floor+0.5)*1pi - (1/((band.floor+0.5)*1pi)),
    scale1 = (band.ceil+0.5)*1pi - (1/((band.ceil+0.5)*1pi));
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
        f[\ltone].(1-phase, n, ~root, {|f,a| SinOsc.ar(f)*a}),
        f[\sincosc].(~root, n),
        f[\ltone].(phase, n, ~root, {|f,a| SinOsc.ar(f)*a})
    ]).sin
};
)

~preout = {};

//sinc drone
(
~preout = {Splay.ar([
    f[\sincosci].(47, 2**SinOsc.ar(1/4/256, 0, 4, 3)+1),
    f[\sincosci].(48, 2**SinOsc.ar(1/5/256, 0, 4, 3)+1),
    f[\sincosci].(49, 2**SinOsc.ar(1/3/256, 0, 4, 3)+1)
]).sin};
)

//stacked sinc drone
(
~preout = {Mix.fill(5, {|i| var
    inc = 2**i,
    beat = (i+1)*0.94,
    root = [1, 9/4, 3, 16/3, 8].at(i)*32,
    period = inc*(i+1)*8,
    dry = Splay.ar([
        f[\sincosci].(root-(1/beat), 2**SinOsc.ar(1/4/period, 0, 4, 3)+1),
        f[\sincosci].(root, 2**SinOsc.ar(1/5/period, 0, 4, 3)+1),
        f[\sincosci].(root+(1/beat), 2**SinOsc.ar(1/3/period, 0, 4, 3)+1)
    ], spread:2/(i+2)).sin;
    GVerb.ar(
        HPF.ar(Mix.new(dry), freq:root*2),
		roomsize:i*10+30, revtime:i+1, damping:0.7, spread:i*20+10,
		earlyreflevel: 0.2,
        drylevel:0, mul:(1-(1/inc))/2
    )+(dry/inc)
})};
)


//shepard timbre
(
~preout = { var
    n = 2,
    period = 0.5,
    pitch = 55,
    partials = 32,
    phase = LFSaw.ar(1/n/period, 0, 1/2, 1/2);
    Splay.ar([
        f[\gtone].(phase, n, {|phase, env| var
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
    chord = [1, 3/2, 8/3].log2,
    root = 110,
    period = 1,
    phase = LFSaw.ar(1/octaves/period, 0, 1/2, 1/2);
    Splay.ar([
        f[\ctone].(phase, octaves, root, f[\voice], chord)
    ]).sin
};
)

s.quit