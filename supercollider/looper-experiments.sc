s.boot

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

// respond to start/stop signal; write loop points into control buses
// start: write phase into loop start bus
// stop: write phase into loop end bus; free recorder
