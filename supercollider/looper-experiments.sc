Server.default = s = Server("belaServer", NetAddr("192.168.7.2", 57110));
s.initTree;
s.startAliveThread;

Server.allRunningServers

s.boot

s.reboot

s.sampleRate

s.query

(
MIDIIn.connectAll;
MIDIFunc.cc({arg val,num,chan,src; "cc %, val:%, chan:%".format(num, val, chan).postln});
MIDIFunc.noteOn({arg val,num,chan,src; "noteOn %, val:%, chan:%".format(num, val, chan).postln});
MIDIFunc.noteOff({arg val,num,chan,src; "noteOff %, val:%, chan:%".format(num, val, chan).postln});
MIDIFunc.bend({arg val,num,chan,src; "bend %, val:%, chan:%".format(num, val, chan).postln});
)


//the number of buffers is set before you boot a server


//records inputs into buffer.
// the `run` argument can be used to start/stop
// `preLevel` is decay factor
// `trigger` jumps to start of buffer
// `doneAction` is used when loop=0 and end of buffer is reached
RecordBuf.ar(inputArray, bufnum: 0, offset: 0.0, recLevel: 1.0, preLevel: 0.0, run: 1.0, loop: 1.0, trigger: 1.0, doneAction: 0)
// lower-level interface:
BufRd.ar(numChannels, bufnum: 0, phase: 0.0, loop: 1.0, interpolation: 2)



//this UGen allocates a local buffer and outputs its address
//i.e. it replaces an external buffer syntactically within a synth
LocalBuf.new(numFrames: 1, numChannels: 1)

// Buffer info UGens adapt when Buffer is changed or reallocated:
BufDur.kr(buf) // gives buffer length
BufRateScale.kr(buf) // gives buffer/server sample rate ratio

//copy data from one buffer to another
Buffer.copyData(buf, dstStartAt: 0, srcStartAt: 0, numSamples: -1)



//method A:
// allocate one 2**24 buffer for initial recording
// use RecordBuf to record
// when stopping, note the recorded length
// allocate a new buffer of the correct length and copy contents
//    for instant looping, the time to allocate and copy may be a problem?
//      in this case, could start playing the rec buffer and later switch to loop

//method B:
// allocate every loop buffer at max length; when done recording, set numFrames (does this work?)
// wastes memory: ~100MB per loop at ~5min/mono/48k
// note BBB has 512MB RAM total
// 5 loops, stereo, max 50s, 48kHz would be ~50*50000*5*2 ~100MB, workable

//method C:
// just use one long buffer for all recording memory; manually track loop points.
// limits total recording to 2**24 samples, though ofc multiple can be used


// consideration: loop crossfade
// method I: ramp in; ramp out and stop ~ms after stop control
//    pro: simple
//    con: adds latency to stop control, adds duck to loop sound

// method II: use two BufRd to procedurally implement crossfade.
// write extra ~ms, but also start fading in immediately (no extra loop length)
//    con: may still soften initial attack; twice the read cost is wasted for majority of loop
//    ext: custom BufRd UGen if efficiency is at stake

// method III: record continuously, just track loop start and end points
//    pro: can crossfade before beginning instead of after end
//         possibility of auto looping (!)
//    con: gets complex when dealing with indexible buffer size limit. not compatible with method C


// verdict: fixed number of maximum-length loops is probably best, will simplify interface and efficiency considerations. does not preclude loop-cloning etc. always-on recording has major appeal.
//    so method B-III it is

(
r.free;
b.free;
p.free;
)

// record continously into a buffer
(
var nchan = 1;
b = Buffer.alloc(s, s.sampleRate*50, nchan);

SynthDef(\recordbuf, { arg inbus = 0, bufnum = 0;
    RecordBuf.ar(In.ar(inbus, nchan), bufnum, loop: 1);
}).add;

r = Synth.new(\recordbuf, [\inbus, s.options.numOutputBusChannels, \bufnum, b]);
)

b.plot

// record continuously with write head output
(
var nchan = 1, buflen = s.sampleRate*50;
b = Buffer.alloc(s, buflen, nchan);
p = Bus.audio(s, 1);

SynthDef(\recordbuf, { arg outbus, inbus, bufnum;
    var phase = Phasor.ar(0, BufRateScale.kr(bufnum), start:0, end:BufFrames.kr(bufnum));
    var input = In.ar(inbus, nchan);
    BufWr.ar(input, bufnum, phase, loop: 1);
    // phase.poll;
    // input.poll;
    Out.ar(outbus, phase)
}).add;

r = Synth.new(\recordbuf, [\outbus, p, \inbus, s.options.numOutputBusChannels, \bufnum, b]);
)

// how to store loop points?
// either bus or buffer;
// could use one 3-channel bus for write, start, end
// -1 to represent a missing value (not writing, not started, not ended)
// in bus case, the recorder has to maintain the signals
// in buffer case, recorder can be freed

// so prefer bus if recorder is going to be kept for overdubbing,
// prefer buffer if a different synth will overdub?

// bus option:
// respond to start/stop signal; write loop points into buses
// start: write phase into loop start bus
// stop: write phase into loop end bus; stop recording
(
var nloop = 3, nchan = 1,
buflen = s.sampleRate*50,
xfadesamps = (s.sampleRate*0.01).floor,
infadeseconds = 0.01;
~buffers !? (_.do(_.free));
~buses !? (_.do(_.free));
~buffers = nloop.collect{Buffer.alloc(s, buflen, nchan)};
~buses = nloop.collect{Bus.audio(s, 3)};

// loop synthdefs
// ==============

SynthDef(\monitor, { arg outbus, inbus;
    EnvGate.new(fadeTime:infadeseconds) * Out.ar(outbus, In.ar(inbus, nchan));
}).add;

//start: begin <- phase, end <- -1
//stop: end <- phase
//recording = (begin<0) | (end<0)
//TODO: after stop, continuously record in the unoccupied part of buffer?
//reset not needed: it always starts at end of prev loop
//problem: phase cannot depend directly on begin/end...
// (Phasor.ar(0, start:0, end:buflen-looplen)+end).wrap(0, buflen)

//currently loop can be re-recorded but this causes a click.
//could go back to single-use recoders
//organize recorders in pairs, keep one recording at all times?
SynthDef(\loop_recorder, { arg outbus, inbus, bufnum;
    var input = In.ar(inbus, nchan);
    var start = T2A.ar(\start.tr(0)), stop = T2A.ar(\stop.tr(0));
    var recording = Schmidt.ar(Impulse.ar(0)+start-stop, -0.5, 0.5);
    var phase = Phasor.ar(
        0, recording*BufRateScale.kr(bufnum), start:0, end:buflen);
    var begin = Latch.ar(phase+xfadesamps+1, start)-1;
    var end = Latch.ar(start.if(0, phase+1), start+stop)-1;//Latch.ar(phase+1, stop)-1;
    BufWr.ar(input, bufnum, phase, loop: 1);
    // recording.poll(5, \rec); begin.poll(5, \begin); end.poll(5, \end);
    Out.ar(outbus, [phase, begin, end])
}).add;
/*SynthDef(\loop_recorder, { arg outbus, inbus, bufnum;
    var input = In.ar(inbus, nchan);
    var start = \start.ar(0), stop = \stop.ar(0);
    var recording = 1-Latch.ar(1, stop);
    var phase = Phasor.ar(
        0, recording*BufRateScale.kr(bufnum), start:0, end:buflen);//BufFrames.kr(bufnum));
    BufWr.ar(input, bufnum, phase, loop: 1);
    // recording.poll(5, \rec);
    Out.ar(outbus, [phase, Latch.ar(phase+1, start)-1, Latch.ar(phase+1, stop)-1])
}).add;*/

//note: phasor reset may not be useful; will click
SynthDef(\loop_player, { arg outbus, inbus, bufnum;
    var in = In.ar(inbus, 3), begin = in[1], end = in[2];
    var unwrap_end = (end<begin)*buflen + end;
    var playing = (begin>0)*(end>0);
    var rate = \rate.ar(1);
    var phase1 = Phasor.ar(
        rate:rate*playing*BufRateScale.kr(bufnum), start:begin, end:unwrap_end,
        trig:playing, resetPos:begin
    );
    var phase2 = phase1.wrap(begin-xfadesamps, unwrap_end-xfadesamps);
    var ramp = (unwrap_end-phase1 /xfadesamps).clip(0, 1);
    var signal1 = BufRd.ar(nchan, bufnum, phase1.wrap(0, buflen), loop:1, interpolation:3);
    var signal2 = BufRd.ar(nchan, bufnum, phase2.wrap(0, buflen), loop:1, interpolation:3);
    var signal = EnvGate.new(fadeTime:infadeseconds) * XFade2.ar(signal2, signal1, ramp*2-1);
    Out.ar(outbus, signal);
}).add;

/*SynthDef(\listener, { arg outbus, inbus;
    var in = In.ar(inbus, nchan);
    var feat = ZeroCrossing.ar(in);
    Out.ar(outbus, feat);
}).add;*/

SynthDef(\conditional_player, { arg outbus, inbus, condbus, bufnum;
    var in = In.ar(inbus, 3), begin = in[1], end = in[2];
    var unwrap_end = (end<begin)*buflen + end;
    var condin = Mix.ar(In.ar(condbus, nchan));
    var feat = 16*Amplitude.ar(condin, 0.003, 0.5);
    var playing = (begin>0)*(end>0);
    var rate = \rate.ar(1) * (1-(feat/(1+feat.abs)));
    var phase1 = Phasor.ar(0, rate*playing*BufRateScale.kr(bufnum), start:begin, end:unwrap_end);
    var phase2 = phase1.wrap(begin-xfadesamps, unwrap_end-xfadesamps);
    var ramp = (unwrap_end-phase1 /xfadesamps).clip(0, 1);
    var signal1 = BufRd.ar(nchan, bufnum, phase1.wrap(0, buflen), loop:1, interpolation:3);
    var signal2 = BufRd.ar(nchan, bufnum, phase2.wrap(0, buflen), loop:1, interpolation:3);
    var signal = EnvGate.new(fadeTime:infadeseconds) * XFade2.ar(signal2, signal1, ramp*2-1);
    signal = FreqShift.ar(signal, feat*100);
    Out.ar(outbus, signal);
}).add;
)

// input monitoring:
//     acoustic source: no monitor
//     intermittent source: always monitor? (to where?)
//     continuous source: monitor while recording

// 'true' looping:
//  fade source instead of playback, overdub immediately
//  works for silenceable sources
//  approach taken here is better for continous sources

(
var inbus = s.options.numOutputBusChannels;
var nslot = 2;

~recorders = ~buffers.collect{nil}; //Array of recorders
~slots = Array.newClear(nslot); //Array of recorder index or nil
~recorder_pool = Set.new; //set of recorder index
~monitors = Dictionary.new; //bus index -> monitor synth
~players = Dictionary.new; //player tag -> player synth
~players_by_loop = Array.fill(~recorders.size, {Set.new}); //recorder index -> Set[player tag]

// loop functions
// ==============

//replace the recorder at index `i`
~record = {arg i;
    ~recorders[i] !? (_.free);
    ~recorders[i] = Synth.new(\loop_recorder, [
        \outbus, ~buses[i], \inbus, inbus, \bufnum, ~buffers[i]]);
    ~recorder_pool.add(i);
};

//create a monitor on bus `out`
~monitor = {arg out;
    "monitor %".format(out).postln;
    ~monitors.add(out -> Synth.tail(s, \monitor, [
        \outbus, out, \inbus, inbus]))
};

//inform recorder `i` of loop begin
~start = {arg i; ~recorders[i].set(\start, 1)};

// inform recorder `i` of loop end
~stop = {arg i; ~recorders[i].set(\stop, 1)};

// make a new player of loop `in` on bus `out`
~play = {arg in, out;
    var player = Synth.tail(s, \loop_player, [
        \outbus, out, \inbus, ~buses[in], \bufnum, ~buffers[in]]);
    var tag = (1 << 30).rand.asHexString;
    "player %".format(tag).postln;
    ~players.add(tag -> player);
    ~players_by_loop[in].add(tag);
    player
};

// free player `tag`
~free_player = {arg tag, fadeTime=0.01; ~players[tag].release(fadeTime)};

// free all players of loop `i`
~free_loop_players = {arg i, fadeTime=0.01;
    ~players_by_loop[i].do{arg j; ~players[j].release(fadeTime); ~players.removeAt(j)};
    "freed players %".format(~players_by_loop[i]);
};

// free monitor on bus `i`, if there is one
~free_monitor = {arg i; ~monitors[i] !? (_.release)};

//TODO: update
~playc = {arg in, out, cond;
    var player = Synth.tail(s, \conditional_player, [
        \outbus, out, \inbus, ~buses[in], \condbus, cond, \bufnum, ~buffers[in]]);
    var tag = ~players.size;
    ~recorders[in].set(\stop, 1);
    "player %".format(tag).postln;
    ~players.add(tag -> player);
    ~players_by_loop[in].add(tag);
    player
};


//remove recorder from the slot, release all its players and then call record on it
~free_slot = {arg slot;
    ~slots[slot] !? {arg rec;
        ~free_loop_players.(rec);
        ~slots[rec] = nil;
        ~record.(rec) //TODO: wait until players freed
    };
};

// start a loop on slot `slot`:
// if the slot has a recorder, release it
// place an available recorder in the slot, and call start on it
// if `monitor` is not nil, make a monitor on bus `monitor`
~start_slot = {arg slot, monitor=nil;
    var new_rec;
    ~free_slot.(slot);
    new_rec = ~recorder_pool.pop; //this will error of there are no recorders
    ~start.(new_rec);
    monitor !? ~monitor;
    ~slots[slot] = new_rec;
};

// if slot is empty, do nothing
// inform loop in `slot` of loop end.
// create a player on bus `out` for the loop in `slot`
// if `monitor` is not nil, free the monitor on bus `monitor`
~play_slot = {arg slot, out, monitor=nil;
    var rec = ~slots[slot];
    if (rec.notNil) {
        monitor !? ~free_monitor;
        ~stop.(rec); //NOTE: currently works but may be fragile; don't want to set a new end point
        ~play.(rec, out)
    } {
        "slot % is empty".format(slot).postln;
    }
};


// init recorders
// ==============

~recorders.size.do{arg i; ~record.(i)};


// MIDI controls
// =============

~slot_notes = [71,69]; //slot index -> MIDI note

~slots.size.do{arg i;
    var note = ~slot_notes[i];
    //start on key down, play on key up
    //here, recorder and player index are tied
    MIDIdef.noteOn("loop_%_start".format(i), {~start_slot.(i, monitor:nil)}, noteNum:note);
    MIDIdef.noteOff("loop_%_play".format(i), {~play_slot.(i, out:i, monitor:false)}, noteNum:note);
    //reset on adjacent black key
    MIDIdef.noteOn("loop_%_reset".format(i), {~record.(i); ~free_loop_players.(i)}, noteNum:note-1);
};

// MIDIdef.noteOn(\loop_1_start, {~start.(1, monitor:1)}, noteNum:71);
// MIDIdef.noteOff(\loop_1_play, {~play.(1, out:1, monitor:false)}, noteNum:71);

MIDIdef.cc(\player_0_rate, {arg val; ~players[0].set(\rate, 2**(val/127-0.5*6))}, ccNum:1);
MIDIdef.cc(\player_1_rate, {arg val; ~players[1].set(\rate, 2**(val/127-0.5*6))}, ccNum:2);
MIDIdef.cc(\player_2_rate, {arg val; ~players[2].set(\rate, 2**(val/127-0.5*6))}, ccNum:3);
MIDIdef.cc(\player_3_rate, {arg val; ~players[3].set(\rate, 2**(val/127-0.5*6))}, ccNum:4);

/*MIDIdef.noteOn(\reset_on, {~reset_modal=true}, noteNum:70);
MIDIdef.noteOff(\reset_off, {~reset_modal=false}, noteNum:70);*/


// idea: give each player its own bus; add a pan control using Xout
// use 2d grid of controls for source/conditional for playc
)

// actions
// =======

(
fork {
    ~start_slot.(0, monitor:0);
    1.wait;
    ~play_slot.(0, out:0, monitor:0);
    "slots: %; pool: %".format(~slots, ~recorder_pool).postln
};
)

(
fork {
    ~start_slot.(1, monitor:1);
    1.wait;
    ~play_slot.(1, out:1, monitor:1);
    "slots: %; pool: %".format(~slots, ~recorder_pool).postln
};
)

t = {SinOsc.ar(443, mul:0.2)}.play(s, s.options.numOutputBusChannels)
t.free

~monitor.(1)
~monitors[0].release

~buffers[0].plot

~start.(0, monitor:0)

~play.(0, out:0, monitor:false)

~play.(0, 1).set(\rate, 1.01)

~players[0].set(\rate, 2.5)

~players[1].set(\rate, 3)

~play.(1,0).set(\rate, 0.751)

~playc.(in:0, out:1, cond:0).set(\rate, 0.5)

~playc.(in:0, out:0, cond:1).set(\rate, 0.5)

~free_player.(0);

s.freeAll

// (
// ~recorders[0].set(\start, 1);
// ~recorders[1].set(\start, 1)
// )
//
// ~recorders[0].set(\stop, 1)
// ~recorders[1].set(\stop, 1)

s.queryAllNodes
s.numSynthDefs