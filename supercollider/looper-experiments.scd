// TODO:

// is it possible to just reduce the length of a buffer and actually free the extra memory?

//   for precise timing:
//     generate the control signals for a recorder or otherwise set the data buffer;
//     ensure a player is already created and will start as soon as buffer is set
//     ^ this is limited to block alignment with buffer endpoints :(
//       there were good reasons to go to buffer though -- generalizes better
//       there is prob a way to jump the player ahead a few samples?

//   understand buses as synth parameters -- do you get free crossfade?
//     InBus works for explicit fade between adjacent buses
//   use the Monitor class?
//     my monitor synth splays a mono input to a stereo output

//  patch everything with Ndef?

//  resolve player slot / recorder slot naming confusion


Server.default = s = Server("belaServer", NetAddr("192.168.7.2", 57110));
s.initTree;
s.startAliveThread;

s.options.numInputBusChannels = 8
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

(
~osc_source = NetAddr("localhost");
OSCFunc.trace;
)

n.sendMsg("/test", 1.0);


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
// eviction policy: oldest material which is not explicitly in a loop gets recorded over
// would allow each loop to record every player for conditioning on,
// without the quadratic complexity that would imply for option B.
// would require some complicated linked-list scheme though?
// probably lose the ability to use the loop buffer normally, need a custom reader...


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
var nloop = 4, nchan = 1,
buflen = s.sampleRate*50,
xfadesamps = (s.sampleRate*0.01).floor,
infadeseconds = 0.01;

~buffers !? (_.do(_.free));
~buffers = nloop.collect{Buffer.alloc(s, buflen, nchan)};

~data_buffers !? (_.do(_.free));
~data_buffers = nloop.collect{Buffer.alloc(s, 2)};

// loop synthdefs
// ==============

// simple monitor
// assume inbus is mono
// use balance argument to distribute across outbus channels if applicable
SynthDef(\monitor, { arg outbus, inbus, gain=1;
    // TODO: should mixdown input here?
    EnvGate.new(fadeTime:infadeseconds) * gain * Out.ar(outbus, In.ar(inbus, nchan));
}).add;
SynthDef(\monitor2, { arg outbus, inbus, balance=0.5, gain=1;
    EnvGate.new(fadeTime:infadeseconds) * Out.ar(
        outbus, gain * Splay.ar(In.ar([inbus], nchan), center:balance));
}).add;

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


SynthDef(\loop_player, { arg outbus, bufnum, databuf;
    // TODO: can these BufRd be kr?
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
    var signal = XFade2.ar(signal2, signal1, ramp*2-1);
    // playing.poll(5, \playing); begin.poll(5, \begin); end.poll(5, \end);
    Out.ar(outbus, EnvGate.new(fadeTime:infadeseconds) * signal);
}).add;

SynthDef(\listener, { arg outbus, inbus;
    var in = InFeedback.ar(inbus, nchan);
    // var feat = K2A.ar(FluidPitch.kr(Mix.ar(in), algorithm:2, maxFreq:3000)[0]);
    var feat = ZeroCrossing.ar(Mix.ar(in));
    // var feat = 16*Amplitude.ar(Mix.ar(in), 0.003, 0.5);
    Out.ar(outbus, feat);
}).add;

SynthDef(\conditional_player, { arg outbus, condbus, bufnum, databuf;
    var begin = BufRd.ar(1, databuf, DC.ar(0), interpolation:1);
    var end = BufRd.ar(1, databuf, DC.ar(1), interpolation:1);
    var unwrap_end = (end<begin)*buflen + end;
    var condin = In.ar(condbus, 1);
    var playing = (begin>=0)*(end>=0);
    var rate = \rate.ar(1) ;//* (1-(condin/(1+condin.abs)));
    var phase1 = Phasor.ar(
        0, rate*playing*BufRateScale.kr(bufnum), start:begin, end:unwrap_end);
    var phase2 = phase1.wrap(begin-xfadesamps, unwrap_end-xfadesamps);
    var ramp = (unwrap_end-phase1 /xfadesamps).clip(0, 1);
    var signal1 = BufRd.ar(nchan, bufnum, phase1.wrap(0, buflen), loop:1, interpolation:3);
    var signal2 = BufRd.ar(nchan, bufnum, phase2.wrap(0, buflen), loop:1, interpolation:3);
    var signal = XFade2.ar(signal2, signal1, ramp*2-1);
    // var freq = K2A.ar(FluidPitch.kr(signal, algorithm:2, maxFreq:3000)[0]);
    var freq = ZeroCrossing.ar(signal);
    signal = FreqShift.ar(signal, condin-freq);
    // signal = Lag.ar(condin>0, 0.03) * FreqShiftAA.ar(signal, Lag.ar(Median.ar(5, condin-freq), 0.03));
    Out.ar(outbus, EnvGate.new(fadeTime:infadeseconds) * signal);
}).add;
)

// input monitoring:
//     acoustic source: no monitor
//     intermittent source: always monitor? (to where?)
//     continuous source: monitor while recording
//         manually start monitor, auto stop monitor on record end

// 'true' looping:
//  fade source instead of playback, overdub immediately
//  works for silenceable sources
//  approach taken here is better for continuous sources

// buses for player outputs / conditional inputs:
// every player should be able to listen to every other
// so each (conditional) player needs a listener
// listers should run with InFeedback before any players
// then players can freely read the listener buses and write their output buses
// so that's 2 buses per player

(
var inbus = s.options.numOutputBusChannels+4;
var rec_nslot = 3;
var play_nslot = 8;

~slot_recorders !? ~slot_recorders.do{_!?~free_rec_slot};

~recorders = ~buffers.collect{nil}; //Array of recorders
~players_by_loop = Array.fill(~recorders.size, {Set.new}); //recorder index -> Set[player tag]

~slot_recorders = Array.newClear(rec_nslot); //Array of recorder index or nil
~slot_players = Dictionary.new;//Array.newClear(play_nslot); //player slot index -> player tag

~recorder_pool = Set.new; //set of recorder index

~input_monitors = Dictionary.new; //recorder index -> monitor synth

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
    var balance = (out%1)*2-1;
    out = out.floor;
    if(s.options.numOutputBusChannels-1>out) {
        "monitor bus % to % balance %".format(in, out, balance).postln;
        Synth.tail(s, \monitor2, [\outbus, out, \inbus, in, \balance, balance]);
    }{
        "monitor bus % to %".format(in, out).postln;
        Synth.tail(s, \monitor, [\outbus, out, \inbus, in]);
    };
};

//create an input monitor on bus `out`
// NOTE: currently all recorders have the same input
// rec_slot is used to associate a monitor with a recorder slot so it can be freed
// when the recorder is freed or stopped
~monitor_input = {arg out, rec_slot;
    ~input_monitors.add(rec_slot -> ~monitor.(out, inbus));
};

//create n monitor for player `tag` on bus `out`
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

//TODO: free player by slot

// free player `tag`
~free_player = {
    arg tag, fadeTime=0.01;
    ~players[tag].release(fadeTime);
    ~player_monitors[tag].release(fadeTime);
    ~player_listeners[tag] !? (_.release(fadeTime));
    ~slot_players.removeAt(~slot_players.findKeyForValue(tag));
    ~players.removeAt(tag);
    ~players_by_loop.do(_.remove(tag));
    "freeing player %".format(tag).postln
    /*fork {
        fadeTime.wait;
        //TODO: what what happens when a player is freed which is being listened to?
        // want to free the player's bus, but actually the listener still needs it
        // apparently need to reference-count users of these buses?
        // for now just don't free it
        // ~player_outputs[tag].free;
        // ~listener_outputs[tag] !? (_.free);
    };*/
};

// free all players of loop `rec`
~free_loop_players = {arg rec, fadeTime=0.01;
    var players = ~players_by_loop[rec].asArray.postln;
    players.do(~free_player);
};

// free monitor for recorder `rec`, if there is one
// TODO: harmless error, need to delete from ~input_monitors
~free_input_monitor = {arg rec;
    ~input_monitors[rec] !? (_.release);
    ~input_monitors.removeAt(rec);
    "freed monitor for recorder %".format(rec).postln
};

/*// make a new listener to in_tag and for out_tag
// NOTE: assuming here listeners output single channel
// removed this because the listener is actually needed before out_tag is available
~listen = {arg out_tag, in_tag;
    var out = Bus.audio(s, 1);
    var listener = Synth.head(s, \listener, [
        \outbus, out, \inbus, ~player_outputs[in_tag]]);
    ~player_listeners.add(out_tag -> listener);
    ~listener_outputs.add(out_tag -> out);
    "% listening to %".format(out_tag, in_tag).postln
};*/

//remove recorder from the slot, release all its players and then call record on it
~free_rec_slot = {arg slot;
    ~slot_recorders[slot] !? {arg rec;
        ~free_loop_players.(rec);
        ~slot_recorders[slot] = nil;
        fork {
            0.1.wait;
            ~record.(rec) //TODO: properly wait until players freed
        };
    };
};

// free player in slot
~free_slot = {arg slot;
    var player = ~slot_players[slot];
    ~free_player.(player);
};

// TODO: gain is not remembered
~mute_slot = {arg slot;
    var player = ~slot_players[slot];
    ~player_monitors[player].set(\gain, 0);
};
~unmute_slot = {arg slot;
    var player = ~slot_players[slot];
    ~player_monitors[player].set(\gain, 1);
};
// TODO: pause slot?


// start a loop in slot `slot`:
// if the slot has a recorder, release it
// place an available recorder in the slot, and call start on it
// if `monitor` is not nil, make a monitor on bus `monitor`
~start_slot = {arg slot, monitor=nil;
    var new_rec;
    ~free_rec_slot.(slot);
    new_rec = ~recorder_pool.pop; //this will error if there are no recorders
    ~start.(new_rec);
    if(monitor.notNil && ~auto_monitor) {~monitor_input.(monitor, slot)};
    ~slot_recorders[slot] = new_rec;
};

//TODO: make play* a special case of playc*

~alloc_player_slot = {arg tag;
    var slot = (0..play_nslot-1).select({arg i; ~slot_players[i].isNil})[0];
    ~slot_players.add(slot -> tag);
    "player % in slot %".format(tag, slot).postln;
};

// if slot is empty, do nothing
// inform recorder in `slot` of loop end.
// create a player for the loop in `slot`
// if `out` is not nil, create a monitor from the player's bus to the bus `out`
// if `free_monitor` is true, free the input monitor for the recorder in `slot`
~play_slot = {arg slot, out=nil, free_monitor=true;
    var tag;
    var player_slot;
    var rec = ~slot_recorders[slot];
    if (rec.notNil) {
        if(free_monitor) {~free_input_monitor.(rec)} {};
        ~stop.(rec); //NOTE: currently works but may be fragile; don't want to set new endpoint
        tag = ~play.(rec);
        out !? {~monitor_player.(out, tag)};
        ~alloc_player_slot.(tag);
        ~players[tag]
    } {
        "slot % is empty".format(slot).postln;
    }
};

// if slot is empty, do nothing
// inform recorder in `slot` of loop end.
// create a listener to player `cond`
// create a conditonal_player using the recorder in `slot` and the new listener
// if `out` is not nil, create a monitor from the player's bus to the bus `out'
// if `free_monitor` is true, free the input monitor for the recorder in `slot`
~playc_slot = {arg slot, out, cond, free_monitor=true;
    var tag;
    var player_slot;
    var listener;
    var listener_out;
    var rec = ~slot_recorders[slot];
    if (rec.notNil) {
        if(free_monitor) {~free_input_monitor.(rec)} {};
        ~stop.(rec); //NOTE: currently works but may be fragile; don't want to set new endpoint
        listener_out = Bus.audio(s, 1);
        listener = Synth.head(s, \listener, [
            \outbus, listener_out, \inbus, ~player_outputs[cond]]);
        tag = ~playc.(rec, listener_out);
        //TOFO
        out !? {~monitor_player.(out, tag)};
        ~alloc_player_slot.(tag);
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

~slot_notes = [71,69,67]; //slot index -> MIDI note
~slot_bal = [0.5, 0, 1];

~auto_monitor = true;

~slot_recorders.size.do{arg i;
    var note = ~slot_notes[i];
    var bal = ~slot_bal[i];
    //start on key down, play on key up
    //here, recorder and player index are tied
    MIDIdef.noteOn("loop_%_start".format(i), {~start_slot.(i, monitor:bal)}, noteNum:note);
    MIDIdef.noteOff("loop_%_play".format(i), {~play_slot.(i, out:bal, free_monitor:true)}, noteNum:note);
    //reset on adjacent black key
    MIDIdef.noteOn("loop_%_reset".format(i), {~free_rec_slot.(i)}, noteNum:note-1);
};

// MIDIdef.noteOn(\loop_1_start, {~start.(1, monitor:1)}, noteNum:71);
// MIDIdef.noteOff(\loop_1_play, {~play.(1, out:1, monitor:false)}, noteNum:71);

play_nslot.do{arg i;
    MIDIdef.cc("player_%_rate".format(i),
        {arg val; ~set_slot.(i, \rate, 2**(val/127-0.5*6))},
        ccNum:i+1);
};

MIDIdef.all.postln;

/*MIDIdef.noteOn(\reset_on, {~reset_modal=true}, noteNum:70);
MIDIdef.noteOff(\reset_off, {~reset_modal=false}, noteNum:70);*/


// OSC controls
// =============

~slot_recorders.size.do{arg i;
    var bal = ~slot_bal[i];
    var path = "rec_%".format(i);
    OSCdef(path, { |msg, time, addr, recvPort|
        "msg: % \t time: % \t addr: % \t recvPort: %".format(msg, time, addr, recvPort).postln;
        ~start_slot.(i, monitor:bal);
    }, path, ~osc_source, argTemplate:[1.0]);
};


//
// ============

// read loop data into a FloatArray
~readback = {arg rec, dst;
    var buf = ~buffers[rec], data_buf = ~data_buffers[rec];
    data_buf.getn(0, 2, {
        arg bounds;
        var begin = bounds[0].postln;
        var end = bounds[1].postln;
        buf.getToFloatArray(begin, end-begin, action:{
            arg result; currentEnvironment[dst]=result.postln
        })
    })
}
)
// ~readback.(0, \data_0)
// ~data_0

//TODO: slot naming off by one

//TODO: condition on slot
// 1. initially
// 2. persistently to slot occupant
// hmmm... implies there should be 1 bus per player not per slot
// and cap number of players?
// don't want to lose possibility of slotless players;
// could manage handoff of bus maybe when one player replaces another?


// TODO before jack demo:
// mixer input
// check monitoring / MIDI to start monitor
// clicks?
// use zero crossing / audition fsaa

// actions
// =======
~data_buffers[0].plot
~buffers[0].plot


// input monitoring
~auto_monitor = false;
~monitor_input.(0.5, rec_slot:0);
~monitor_input.(0, rec_slot:1);
~monitor_input.(1, rec_slot:2);


// record with approximate timing
(
fork {
    var bal=0.5;
    ~start_slot.(0, monitor:bal);
    2.wait;
    ~play_slot.(0, out:bal, free_monitor:true);
    // "slots: %; pool: %".format(~slot_recorders, ~recorder_pool).postln
    };
)

(
fork {
    var bal=0;
    ~start_slot.(1, monitor:bal);
    2.wait;
    ~playc_slot.(1, out:bal, cond:~slot_players[0], free_monitor:true);
    // "slots: %; pool: %".format(~slot_recorders, ~recorder_pool).postln
};
)

(
fork {
    var bal=1;
    ~start_slot.(2, monitor:bal);
    2.3.wait;
    ~playc_slot.(2, out:bal, cond:~slot_players[1], free_monitor:true);
    // "slots: %; pool: %".format(~slot_recorders, ~recorder_pool).postln
};
)

// free recorders and all connected players
~free_rec_slot.(0)
~free_rec_slot.(1)
~free_rec_slot.(2)

// free players
~free_slot.(0)
~free_slot.(1)
~free_slot.(2)
~free_slot.(3)
~free_slot.(4)
~free_slot.(5)
~free_slot.(6)
~free_slot.(7)

// new player for an existing recorder
~play_slot.(0, out:0.75).set(\rate, 1.25)
~play_slot.(0, out:0.25).set(\rate, 1.125)
~play_slot.(0, out:0).set(\rate, 0.5)
~play_slot.(0, out:1).set(\rate, 0.75)
~play_slot.(1, out:0.75).set(\rate, 0.5)


// new conditional player for an existing recoder
~playc_slot.(0, out:0, cond:~slot_players[0]).set(\rate, 0.5)
~playc_slot.(0, out:1, cond:~slot_players[0]).set(\rate, 0.5)

// player rate
~set_slot.(0, \rate, 0.35)
~set_slot.(1, \rate, 0.33)
~set_slot.(2, \rate, 3)
~set_slot.(3, \rate, 0.03)
~set_slot.(4, \rate, 0.01)
~set_slot.(5, \rate, 1)
~set_slot.(6, \rate, 1)
~set_slot.(7, \rate, 1)

~mute_slot.(1)
~unmute_slot.(1)



s.record
s.stopRecording

// ===========
// debug

~players
~players_by_loop
~slot_players
~slot_recorders
~input_monitors


t = {SinOsc.ar(400, mul:0.2)}.play(s, s.options.numOutputBusChannels)
t.free


// verbose set_slot
~players[~slot_players[2]].set(\rate, 1.5)

// player by tag
~players["1B17DC7A"].set(\rate, 0.0125)

s.freeAll

s.queryAllNodes
s.numSynthDefs