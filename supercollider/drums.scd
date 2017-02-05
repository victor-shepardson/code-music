s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.boot
s.quit

s.queryAllNodes

p = ProxySpace.push(s);

MIDIIn.connectAll;
MIDIdef.freeAll;

MIDIdef.noteOn(\test1, {arg ...args; "on".postln; args.postln}); // match any noteOn
MIDIdef.noteOff(\test2, {arg ...args; "off".postln; args.postln}); // match any noteOff

(
p.clear;
~out.ar(2);
~out.play;

~kfund = 1;
~k0 = {Trig1.ar(\trig.kr, 1/SampleRate.ir)};
~ke = {[0.7,1,0.6,0.5]*Decay2.ar(~k0.ar, 0.005, \dur.kr*[1.0, 0.7, 0.5, 0.3])};
~kf = {\mult.kr*~kfund*[1,2,3,4]*(2**([2,3,4,5]*(Decay2.ar(~k0.ar, [0.05, 0, 0, 0], [0.3, 0.15, 0.1, 0.05]))))};
~k1 = {~ke.ar*SinOsc.ar(~kf.ar)};
~k2 = {Limiter.ar(Mix.ar(~k1.ar)*4)};
~kick = {[~k2.ar, ~k2.ar]};
MIDIdef.noteOn(\kick_on, {|val,num,chan,src|
	~ke.set(\dur, val/64);
	~kf.set(\mult, num);
	~k0.set(\trig, 1)
},nil,0);
MIDIdef.noteOff(\kick_off, {|val,num,chan,src| ~k0.set(\trig, 0)},nil,0);


~h0 = {Trig1.ar(\trig.kr, 1/SampleRate.ir)};
~he = {[0.2,0.1,1,0.6,0.5]*Decay2.ar(~h0.ar, 0.00, \dur.kr*[0.5, 0.55, 0.7, 0.5, 0.3])};
~h1 = {~he*BHiPass4.ar(Crackle.ar(1.9), 1000*[3.3,2,5.2,5.1,8], 0.002)};
~h2 = {Limiter.ar(Splay.ar(~h1.ar.scramble)*1)};
~hat = {[~h2.ar, ~h2.ar]};
MIDIdef.noteOn(\hat_on, {|val,num,chan,src|
	~he.set(\dur, val/64);
	// ~hf.set(\mult, num);
	~h0.set(\trig, 1);
},nil,1);
MIDIdef.noteOff(\hat_off, {|val,num,chan,src| ~h0.set(\trig, 0)},nil,1);

~out = ~hat*0.5;
~out = ~kick*0.4 + (~hat*0.3);
)