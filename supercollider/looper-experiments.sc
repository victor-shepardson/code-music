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

s.options.numAudioBusChannels - s.options.numInputBusChannels - s.options.numOutputBusChannels


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
~buffers = nloop.collect{Buffer.alloc(s, buflen, nchan)};

~data_buffers !? (_.do(_.free));
~data_buffers = nloop.collect{Buffer.alloc(s, 2)};

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
/*SynthDef(\loop_recorder, { arg outbus, inbus, bufnum;
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
}).add;*/
SynthDef(\loop_recorder, { arg inbus, bufnum, databuf;
    var input = In.ar(inbus, nchan);
    var start = T2A.ar(\start.tr(0)), stop = T2A.ar(\stop.tr(0));
    // var recording = Schmidt.ar(Impulse.ar(0)+start-stop, -0.5, 0.5);
    var phase = Phasor.ar(
        0, BufRateScale.kr(bufnum), start:0, end:buflen);
    Demand.ar(start, 0, Dbufwr(phase, databuf, 0));
    Demand.ar(stop, 0, Dbufwr(phase, databuf, 1));
    BufWr.ar(input, bufnum, phase, loop: 1);
}).add;

//note: phasor reset may not be useful; will click
/*SynthDef(\loop_player, { arg outbus, inbus, bufnum;
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
}).add;*/
SynthDef(\loop_player, { arg outbus, bufnum, databuf;
    var begin = BufRd.ar(1, databuf, DC.ar(0), interpolation:1);
    var end = BufRd.ar(1, databuf, DC.ar(1), interpolation:1);
    var unwrap_end = (end<begin)*buflen + end;
    var playing = (begin>=0)*(end>=0);
    var rate = \rate.ar(1);
    var phase1 = Phasor.ar(
        rate:rate*playing*BufRateScale.kr(bufnum), start:begin, end:unwrap_end,
        trig:playing, resetPos:begin
    );
    var phase2 = phase1.wrap(begin-xfadesamps, unwrap_end-xfadesamps);
    var ramp = (unwrap_end-phase1 /xfadesamps).clip(0, 1);
    var signal1 = BufRd.ar(nchan, bufnum, phase1.wrap(0, buflen), loop:1, interpolation:4);
    var signal2 = BufRd.ar(nchan, bufnum, phase2.wrap(0, buflen), loop:1, interpolation:4);
    var signal = EnvGate.new(fadeTime:infadeseconds) * XFade2.ar(signal2, signal1, ramp*2-1);
    // playing.poll(5, \playing); begin.poll(5, \begin); end.poll(5, \end);
    Out.ar(outbus, signal);
}).add;

SynthDef(\listener, { arg outbus, inbus;
    var in = InFeedback.ar(inbus, nchan);
    // var feat = ZeroCrossing.ar(Mix.ar(in));
    var feat = 16*Amplitude.ar(Mix.ar(in), 0.003, 0.5);
    Out.ar(outbus, feat);
}).add;

/*SynthDef(\conditional_player, { arg outbus, inbus, condbus, bufnum;
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
)*/
SynthDef(\conditional_player, { arg outbus, condbus, bufnum, databuf;
    var begin = BufRd.ar(1, databuf, DC.ar(0), interpolation:1);
    var end = BufRd.ar(1, databuf, DC.ar(1), interpolation:1);
    var unwrap_end = (end<begin)*buflen + end;
    var condin = In.ar(condbus, 1);
    var playing = (begin>=0)*(end>=0);
    var rate = \rate.ar(1) * (1-(condin/(1+condin.abs)));
    var phase1 = Phasor.ar(
        0, rate*playing*BufRateScale.kr(bufnum), start:begin, end:unwrap_end);
    var phase2 = phase1.wrap(begin-xfadesamps, unwrap_end-xfadesamps);
    var ramp = (unwrap_end-phase1 /xfadesamps).clip(0, 1);
    var signal1 = BufRd.ar(nchan, bufnum, phase1.wrap(0, buflen), loop:1, interpolation:3);
    var signal2 = BufRd.ar(nchan, bufnum, phase2.wrap(0, buflen), loop:1, interpolation:3);
    var signal = EnvGate.new(fadeTime:infadeseconds) * XFade2.ar(signal2, signal1, ramp*2-1);
    signal = FreqShift.ar(signal, condin*100);
    Out.ar(outbus, signal);
}).add;
)

// input monitoring:
//     acoustic source: no monitor
//     intermittent source: always monitor? (to where?)
//     continuous source: monitor while recording

// 'monitor' was originally for monitoring the single input bus, and it was enforced that there could be 1 monitor per output bus.
// however with the move to player/listener buses, a monitor is needed for players
// this means arbitrary number of monitors per output
// can keep the old system, just rename to 'input monitors'
// and add a new 'player attribute' monitor

// 'true' looping:
//  fade source instead of playback, overdub immediately
//  works for silenceable sources
//  approach taken here is better for continous sources

// buses for player outputs / conditional inputs:
// every player should be able to listen to every other
// so each (conditional) player needs a listener
// listers should run with InFeedback before any players
// then players can freely read the listener buses and write their output buses
// so that's 2 buses per player

(
var inbus = s.options.numOutputBusChannels;
var rec_nslot = 2;
var play_nslot = 8;

~slot_recorders !? ~slot_recorders.do{_!?~free_slot};

~recorders = ~buffers.collect{nil}; //Array of recorders
~players_by_loop = Array.fill(~recorders.size, {Set.new}); //recorder index -> Set[player tag]

~slot_recorders = Array.newClear(rec_nslot); //Array of recorder index or nil
~slot_players = Array.newClear(play_nslot); //Array of player tag or nil

~recorder_pool = Set.new; //set of recorder index

~input_monitors = Dictionary.new; //input bus index -> monitor synth

~players = Dictionary.new; //player tag -> player synth
~player_outputs = Dictionary.new; //player tag -> player output bus
~player_listeners = Dictionary.new; //player tag -> listener synth (listener for, not to)
~listener_outputs = Dictionary.new; //player tag -> listener output bus
~player_monitors = Dictionary.new; //player tag -> monitor synth

// loop functions
// ==============

//replace the recorder at index `rec`
~record = {arg rec;
    ~recorders[rec] !? (_.free);
    ~data_buffers[rec].fill(0,2,value:-1);
    ~recorders[rec] = Synth.new(\loop_recorder, [
    // \outbus, ~buses[i], \inbus, inbus, \bufnum, ~buffers[rec]]);
        \inbus, inbus, \bufnum, ~buffers[rec], \databuf, ~data_buffers[rec]]);
    ~recorder_pool.add(rec);
};

// create a monitor from bus `in` to bus `out`
~monitor = {arg out, in;
    Synth.tail(s, \monitor, [\outbus, out, \inbus, in])
};

//create an input monitor on bus `out`
~monitor_input = {arg out;
    "monitor %".format(out).postln;
    ~input_monitors.add(out -> ~monitor.(out, inbus));
};

//create an monitor for player `tag` on bus `out`
~monitor_player = {arg out, tag;
    // "monitor %".format(out).postln;
    ~player_monitors.add(tag -> ~monitor.(out, ~player_outputs[tag]));
};


//inform recorder `rec` of loop begin
~start = {arg rec; ~recorders[rec].set(\start, 1)};

// inform recorder `i` of loop end
~stop = {arg rec;
    var recorder = ~recorders[rec];
    recorder.set(\stop, 1);
    fork{
        0.1.wait;
        recorder.run(false)
    };
};

// make a new player of loop `rec` and assign it a new bus
~play = {arg rec;
    var buf = ~buffers[rec];
    var out = Bus.audio(s, buf.numChannels);
    var player = Synth.tail(s, \loop_player, [
        \outbus, out, \bufnum, buf, \databuf, ~data_buffers[rec]]);
    var tag = (1 << 30).rand.asHexString;
    // "player %".format(tag).postln;
    ~players.add(tag -> player);
    ~player_outputs.add(tag -> out);
    ~players_by_loop[rec].add(tag);
    tag
};

// make a new player of recorder `rec`, conditioned on bus `cond`
~playc = {arg rec, cond;
    var buf = ~buffers[rec];
    var out = Bus.audio(s, buf.numChannels);
    var player = Synth.tail(s, \conditional_player, [
        \outbus, out, \condbus, cond, \bufnum, buf, \databuf, ~data_buffers[rec]]);
    var tag = (1 << 30).rand.asHexString;
    // "player %".format(tag).postln;
    ~players.add(tag -> player);
    ~player_outputs.add(tag -> out);
    ~players_by_loop[rec].add(tag);
    tag
};

// free player `tag`
~free_player = {
    arg tag, fadeTime=0.01;
    ~players[tag].release(fadeTime);
    ~player_monitors[tag].release(fadeTime);
    fork {
        fadeTime.wait;
        //TODO: what what happens when a player is freed which is being listened to?
        // want to free the player's bus, but actually the listener still needs it
        // apparently need to reference-count users of these buses?
        // for now just don't free it
        // ~player_outputs[tag].free;
        ~listener_outputs[tag] !? (_.free);
        ~player_listeners[tag] !? (_.free);
        ~slot_players.replace(tag, nil);
        "freed player %".format(tag).postln
    };
};


// free all players of loop `rec`
~free_loop_players = {arg rec, fadeTime=0.01;
    ~players_by_loop[rec].do(~free_player);
};

// free monitor on bus `out`, if there is one
~free_input_monitor = {arg out; ~input_monitors[out] !? (_.release)};

/*// make a new listener to in_tag and for out_tag
// NOTE: assuming here listeners output single channel
~listen = {arg out_tag, in_tag;
    var out = Bus.audio(s, 1);
    var listener = Synth.head(s, \listener, [
        \outbus, out, \inbus, ~player_outputs[in_tag]]);
    ~player_listeners.add(out_tag -> listener);
    ~listener_outputs.add(out_tag -> out);
    "% listening to %".format(out_tag, in_tag).postln
};*/

//remove recorder from the slot, release all its players and then call record on it
~free_slot = {arg slot;
    ~slot_recorders[slot] !? {arg rec;
        ~free_loop_players.(rec);
        ~slot_recorders[slot] = nil;
        fork {
            0.1.wait;
            ~record.(rec) //TODO: properly wait until players freed
        };
    };
};

// start a loop in slot `slot`:
// if the slot has a recorder, release it
// place an available recorder in the slot, and call start on it
// if `monitor` is not nil, make a monitor on bus `monitor`
~start_slot = {arg slot, monitor=nil;
    var new_rec;
    ~free_slot.(slot);
    new_rec = ~recorder_pool.pop; //this will error if there are no recorders
    ~start.(new_rec);
    monitor !? ~monitor_input;
    ~slot_recorders[slot] = new_rec;
};

// if slot is empty, do nothing
// inform recorder in `slot` of loop end.
// create a player for the loop in `slot`
// if `out` is not nil, create a monitor from the player's bus to the bus `out'
// if `monitor` is not nil, free the input monitor on bus `monitor`
~play_slot = {arg slot, out=nil, monitor=nil;
    var tag;
    var player_slot;
    var rec = ~slot_recorders[slot];
    if (rec.notNil) {
        monitor !? ~free_input_monitor;
        ~stop.(rec); //NOTE: currently works but may be fragile; don't want to set new endpoint
        tag = ~play.(rec);
        out !? {~monitor_player.(out, tag)};
        player_slot = ~slot_players.indexOf(nil);
        ~slot_players[player_slot] = tag;
        "player % in slot %".format(tag, player_slot).postln;
        ~players[tag]
    } {
        "slot % is empty".format(slot).postln;
    }
};
/*// if slot is empty, do nothing
// inform recorder in `slot` of loop end.
// create a player on bus `out` for the loop in `slot`
// if `monitor` is not nil, free the monitor on bus `monitor`
~play_slot = {arg slot, out, monitor=nil;
    var rec = ~slot_recorders[slot];
    if (rec.notNil) {
        monitor !? ~free_monitor;
        ~stop.(rec); //NOTE: currently works but may be fragile; don't want to set a new end point
        ~play.(rec, out)
    } {
        "slot % is empty".format(slot).postln;
    }
};*/

// if slot is empty, do nothing
// inform recorder in `slot` of loop end.
// create a listener to player `cond`
// create a conditonal_player using the recorder in `slot` and the new listener
// if `out` is not nil, create a monitor from the player's bus to the bus `out'
// if `monitor` is not nil, free the input monitor on bus `monitor`
~playc_slot = {arg slot, out, cond, monitor=nil;
    var tag;
    var player_slot;
    var listener;
    var listener_out;
    var rec = ~slot_recorders[slot];
    if (rec.notNil) {
        monitor !? ~free_input_monitor;
        ~stop.(rec); //NOTE: currently works but may be fragile; don't want to set new endpoint
        listener_out = Bus.audio(s, 1);
        listener = Synth.head(s, \listener, [
            \outbus, listener_out, \inbus, ~player_outputs[cond]]);
        tag = ~playc.(rec, listener_out);
        //TOFO
        out !? {~monitor_player.(out, tag)};
        player_slot = ~slot_players.indexOf(nil);
        ~slot_players[player_slot] = tag;
        "player % in slot %".format(tag, player_slot).postln;
        ~player_listeners.add(tag -> listener);
        ~listener_outputs.add(tag -> listener_out);
        "% listening to %".format(tag, cond).postln;
        ~players[tag]
    } {
        "slot % is empty".format(slot).postln;
    }
};

~set_slot = {arg slot, key, val;
    ~players[~slot_players[slot]].set(key, val)
};


// init recorders
// ==============

~recorders.size.do{arg i; ~record.(i)};


// MIDI controls
// =============

~slot_notes = [71,69]; //slot index -> MIDI note

~slot_recorders.size.do{arg i;
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

~slot_players.size.do{arg i;
    MIDIdef.cc("player_%_rate".format(i),
        {arg val; ~set_slot.(i, \rate, 2**(val/127-0.5*6))},
        ccNum:i+1);
};

/*MIDIdef.noteOn(\reset_on, {~reset_modal=true}, noteNum:70);
MIDIdef.noteOff(\reset_off, {~reset_modal=false}, noteNum:70);*/


// idea: give each player its own bus; add a pan control using Xout
// use 2d grid of controls for source/conditional for playc
)

//TODO: condition on slot
// 1. initially
// 2. persistently to slot occupant
// hmmm... implies there should be 1 bus per player not per slot
// and cap number of players?
// don't want to lose possibility of slotless players;
// could manage handoff of bus maybe when one player replaces another?

// actions
// =======
~data_buffers[0].plot
~buffers[0].plot

(
fork {
    ~start_slot.(0, monitor:0);
    1.wait;
    ~play_slot.(0, out:0, monitor:0);
    "slots: %; pool: %".format(~slot_recorders, ~recorder_pool).postln
};
)

(
fork {
    ~start_slot.(1, monitor:1);
    1.5.wait;
    ~playc_slot.(1, out:1, cond:~slot_players[0], monitor:1);
    // ~play_slot.(1, out:1,  monitor:1);
    "slots: %; pool: %".format(~slot_recorders, ~recorder_pool).postln
};
)

~set_slot.(0, \rate, 4)

~set_slot.(1, \rate, 2)

~play_slot.(0, out:1).set(\rate, 4.03125)

~playc_slot.(1, out:0, cond:~slot_players[2]).set(\rate, 2)

~free_slot.(0)
~free_slot.(1)




~players[~slot_players[2]].set(\rate, 1.5)


~play_slot.(1, out:0).set(\rate, 1.75)

~play_slot.(0, out:1).set(\rate, 2.03125)
~players[~slot_players[5]].set(\rate, 4.03125)

~playc_slot.(1, out:0, cond:~slot_players[5]);
~players[~slot_players[6]].set(\rate, 2)



~players["1B17DC7A"].set(\rate, 0.0125)


~playc_slot.(1, out:0, cond:"1B17DC7A", monitor:1);
~players["13C1FE0E"].set(\rate, 0.003125)

~free_player.("2B9E1D65")


~free_slot.(0)

~free_player.(~slot_players[4]);


~players["2535EBD4"].set(\rate, 1)

~free_slot.(1)

t = {SinOsc.ar(443, mul:0.2)}.play(s, s.options.numOutputBusChannels)
t.free

~monitor_input.(1)
~input_monitors[0].release

~buffers[0].plot

~start.(0, monitor:0)

~play.(0, out:0, monitor:false)

~play.(0, 1).set(\rate, 1.01)

~players[0].set(\rate, 2.5)

~players[1].set(\rate, 3)

~play.(1,0).set(\rate, 0.751)

~playc.(in:0, out:1, cond:0).set(\rate, 0.5)

~playc.(in:0, out:0, cond:1).set(\rate, 0.5)

~free_slot.(0);

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

~recorders
~slot_recorders
~recorder_pool
~input_monitors
~players
~players_by_loop

~player_outputs
~player_listeners
~listener_outputs
~player_monitors 