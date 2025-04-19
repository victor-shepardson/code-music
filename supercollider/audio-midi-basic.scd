s.boot;

(
MIDIClient.init;
~midi = MIDIOut.newByName("To iipyper 1", "To iipyper 1").latency_(0);
// ~midi = MIDIOut.newByName("fluidsynth", "fluidsynth").latency_(0);

~get_pitchbend = {
	arg f;
	var semis = (f/440).log2*12;
	semis - semis.round * 16384;
};
Ndef(\analyzer, {
	// var x = SoundIn.ar(0);
	// var x = Mix(SoundIn.ar([6,7]));
	var in = SoundIn.ar([6,7]);

	in.do{ |x,i|
		var pitch = Tartini.kr(x);
		var chain = FFT(LocalBuf(512), x);
		var onsets = Onsets.kr(chain, threshold:0.5, odftype:\rcomplex);
		var del_onsets = Delay1.kr(onsets);
		var amp = Amplitude.kr(x);
		var onset_amp = Latch.kr(amp, del_onsets);
		// subtracting undelayed onsets to ensure offset occurs
		var duty = Schmidt.kr(amp / onset_amp - onsets, 0.1, 0.99);
		var bend = Sanitize.kr(~get_pitchbend.(pitch));

		duty = Trig1.kr(duty, 0.05); // min length + rate limit

		SendReply.kr(duty, '/onset_pitch', [i]++pitch++[onset_amp]);
		SendReply.kr(1-duty, '/onset_pitch', [i]++DC.kr(0));
		SendReply.ar(Impulse.ar(30)*duty, '/bend', bend);
	}

});

// ~get_pitchbend.(879);

~pitch = Dictionary();
OSCdef(\tomidi, {
	arg msg;

	var chan = msg[3].asInteger;
	var f0 = msg[4];
	var confidence = msg[5];
	var amp = msg[6];
	// var pitchbend = ~get_pitchbend.(f0);
	// msg.postln;

	(f0 > 0).if{
		var pitch = f0.cpsmidi.round.asInteger;
		var vel = (amp.clip(0,1).pow(0.25)*127).asInteger;
		~pitch[chan] = pitch;
		// send noteOn
		[chan, pitch, vel].postln;
		~midi.noteOn(chan, pitch, vel);
	}{
		var pitch = ~pitch[chan];
		pitch.notNil.if{
			// send noteOff
			[chan, ~pitch[chan], \off].postln;
			~midi.noteOff(chan, ~pitch[chan], 64);
		}
	}

}, '/onset_pitch');

~bend = 0;
~lag = 0.99;
OSCdef(\bend, {
	arg msg;

	var bend = msg[3].asInteger;
	~bend = ~bend*~lag + (1-~lag*bend);

	// [\bend, bend].postln;
	16.do{ |i| ~midi.bend(i, ~bend)};

}, '/bend')
)

OSCdef.trace(false)

MIDIClient