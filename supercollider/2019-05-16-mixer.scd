(
s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.options.numInputBusChannels = 8;
s.options.numOutputBusChannels = 8;

s.boot
)

s.record("~/record/scratch.wav", 2);
s.stopRecording;

s.queryAllNodes

(
p = ProxySpace.push(s);
MIDIIn.connectAll;
)

s.quit
MIDIdef.freeAll;


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
)


(
var notes_held=0, voices=(-1)!12;
p.clear;
~in.ar(2);
~preout.ar(2);
~out.ar(2);
// ~aux.ar(2);
~out.play;
// ~aux.play(2);

~pitches.kr(12);
~pitches = { \notes.kr((-1)!12)}; //default value is crucial
// ~pitches.set(\notes, [30, 37, 44, 51, 70, 77, 84, 91]);

MIDIdef.noteOn(\set_note, { arg val, num, chan, src;
    // if no notes held, silence all voices
    if(notes_held==0, {voices.fill(-1)});

    // set next voice
    voices[notes_held] = num;
    voices.postln;
    notes_held.postln;

    ~pitches.set(\notes, voices);
    notes_held = notes_held+1;

    //set velocity
    // n[num].set(\vel, val)
},nil,0);

MIDIdef.noteOff(\unset_note, { arg val, num, chan, src;
    notes_held = notes_held-1;
    // n[num].set(\vel, 0)
},nil,0);

// ~in = {SoundIn.ar([0,1])};
~in = {SoundIn.ar([6,7])};
// ~in = {SinOsc.ar([220, 440])};

~a = {Amplitude.ar(~in.ar)};

// ~f = {Tartini.kr(~in.ar)[0]};
~f = {ZeroCrossing.ar(~in.ar)};

~preout = {f[\wiggle].(Splay.ar(
    ~pitches.kr.collect({ arg pitch, i;
        var env = (pitch >= 0);
        var freq = pitch.midicps;
        FreqShift.ar(~in.ar.wrapAt(i), freq-~f.ar.wrapAt(i))*env
    })
), dry: 0, amt: 0.001, rate: 5)};

~verb = {f[\wiggle].(GVerb.ar(Mix.new(~preout.ar),
    roomsize:50, revtime:5, damping:0.4, spread:0.9,
    earlyreflevel: 0.0, drylevel: 0
    ), dry: 1, amt: 0.003, rate: 1)};

// ~preaux = ~in;
// ~preaux = ~preout;
// ~preaux = { ~in.ar.collect({ arg chan;
//     Mix.ar(GVerb.ar(chan, roomsize:50, revtime:5, damping:0.4, spread:1,
//     earlyreflevel: 0.0, drylevel: 0))}
// )};

// ~aux = {0.95*Limiter.ar(0.9*~preaux.ar)};
~out = {0.95*Limiter.ar(LeakDC.ar(~verb.ar*0.03+~preout.ar))};
// ~out = {0.95*Limiter.ar(LeakDC.ar(~preout.ar))};

)

~in.scope
~env.scope
~out.scope
~aux.scope
~i.scope