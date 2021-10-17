s.boot

// record audio into a Buffer
(
//TODO: live recording
~audio = Buffer.read(s,
     PathName("~/code-music/audio2pattern/test.wav").fullPath);
~indices = Buffer.new(s);
)

~audio.query

~audio.plot

// slice audio
(
FluidBufOnsetSlice.processBlocking(s, ~audio, indices: ~indices, threshold:0.5);
~indices.getToFloatArray(action:{arg arr; ~indices_arr=arr})
)

~indices.query

~indices_arr.plot(discrete:true)

// store slices
// TODO: crossfade
(
~sample_path = "~/code-music/audio2pattern/scratch/";
~indices_arr.do{ |x, i|
    var path = PathName(
        ~sample_path++i.asString.padLeft(5,"0")++".aiff");
    File.mkdir(path.pathOnly);
    ~audio.write(
        path.fullPath,
        numFrames: if (i+1<~indices_arr.size) {~indices_arr[i+1] - ~indices_arr[i]} {-1},
        startFrame: ~indices_arr[i]
)}
)

// compute cps from recorded length
// TODO: multi-cycle loops?
~cps = ~audio.sampleRate/~audio.numFrames

// quantize onsets and compute residual nudge
//TODO: check for collisions
(
~quant = 32;
~tactus = ~audio.numFrames/~quant;
~onsets = ~indices_arr/~tactus;
~onsets_quant = ~onsets.round;
~onsets_resid = ~onsets - ~onsets_quant;
// ~onsets_resid.mean

//iteratively increase tactus until there are no collisions?

~onsets_nudge = ~onsets_resid * ~tactus / ~audio.sampleRate;

//map quantized position to sample index
~onset_dict = Dictionary.with(*~onsets_quant.collect({ |x,i| x->i }));
~onset_dict.size == ~onsets.size;

)

~onsets_nudge.plot(discrete:true);

// parse onsets into mini-notation
// simple binary tree case:
(
~walk = { |i=0, res=1|
    if (res >= ~quant) {if (~onset_dict.includesKey(i)) {~onset_dict[i].asString} {"~"}} {
        var left, right;
        left = ~walk.(i, res*2);
        right = ~walk.(~quant/res/2 + i, res*2);
        if (right=="~") {left} {"["++left++" "++right++"]"}
}};
~note_pattern = ~walk.value
)

//TODO: construct the nudge pattern
//TODO: retain pattern structure instead of building strings
//TODO: allow triplets, backtracking search for best grouping?

(
d = SuperDirt(2, s);

d.loadSoundFiles(~sample_path);
d.start(57120);
)