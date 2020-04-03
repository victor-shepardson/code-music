(
s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.options.numWireBufs = 128;
s.boot
)

(
p = ProxySpace.push(s);
f = Environment.new;
)

(
f[\sincextremum] = { |n|
    var q = n+0.5*pi;
    q - (1/q) - (q.pow(-3)*2/3)
};

f[\sinc] = { |phi| var zero = (phi.abs<1e-8); phi.sin+zero/(phi+zero)};


f[\sincosc] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, iphase=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:iphase),
    band_ = band.min(cutoff/freq).max(0).floor+1,
	scale = f[\sincextremum].(band_);
    f[\sinc].(phi*scale+pm)-(0.5pi/scale*fixdc)*mul*EnvGate.new+add
};

f[\sincosci] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor).max(0)+1,
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil),
    osc0 = f[\sinc].(phi*scale0+pm)-(0.5pi/scale0*fixdc),
    osc1 = f[\sinc].(phi*scale1+pm)-(0.5pi/scale1*fixdc);

    m*osc1+(1-m*osc0)*mul*EnvGate.new+add
};

f[\poly] = { |x, s_i, v_f|
    var x_ = x.abs;
    s_i-v_f/2*x_ - (s_i-v_f*3/2)*x_ + s_i*x_ * x.sign
};
f[\sincosci2] = { |freq, band=0, mul=1, add=0, cutoff=24000, pm=0, fixdc=1|
    var phi = LFSaw.ar(freq, iphase:0),
    band_ = band.min((cutoff/freq).floor).max(0)+1,
    m = band_%1,
	scale0 = f[\sincextremum].(band_.floor),
    scale1 = f[\sincextremum].(band_.ceil),
    scale = f[\sincextremum].(band_),
    x0 = f[\poly].(phi, scale, scale0),
    x1 = f[\poly].(phi, scale, scale1),
    osc0 = f[\sinc].(x0+pm)-(0.5pi/scale0*fixdc),
    osc1 = f[\sinc].(x1+pm)-(0.5pi/scale1*fixdc);

    m*osc1+(1-m*osc0)*mul*EnvGate.new+add
};
)
(
var fund = 9;
// var tune = 3;
// var tune = [1, 3, 1/3, 9, 1/9, 27, 1/27, 81, 1/81];
// var tune = [1, 1/3, 3, 1, 1/3, 3, 9, 1/9, 1/27];
// var tune = [1, 1/3, 1/9, 1, 3, 9, 3, 1/3, 1];
/*var tune = [1, 3/11, 3/5, 1/3, 3, 3/7, 1, 3/5, 3];*/
/*var tune = [1, 3, 3/5, 3/7, 3/11, 3/5, 1, 1/3, 3];*/
// var tune = Array.fill(9, {arg i; (pi/2)**i});
var tune = Array.fill(3, {arg i; i.exp}) ++ Array.fill(3, {arg i; 3*i.exp}) ++ Array.fill(3, {arg i; 5*i.exp});

var interval = { arg degree, octave;
    // 2.pow(tune.pow(degree).log2%1+octave)
    // 2.pow(degree.nthPrime.log2%1+octave)
    // 2.pow((degree*2+1).log2%1+octave)
    2.pow(tune[degree].log2%1+octave)
};
var n = 9;
var r = 1/60;//1/90;//1/120;
var partials = [9, 6, 3, 6, 3, 3, 3, 2, 3/2]*4/3;
var r_partials = [1, 1, 1, 1, 1, 1/2, 1/4, 1/4, 1/2];
var phase = [0, -1/8, -1/8, -1/4, -3/8, -1/2, -1/4, -1/8, -1/4];
// var r_amp = [1, 3/2, -1/2, 1/3, 1/5, -1/7, 3/7, 4/9, 5/11];
var r_amp = [1, 3/2, -1/2, 1/3, 2/3, -1/7, 3/7, 2/5, 3/5];
// var fm_f = 1/[[2, 4], [2, 4], [2, 4], [3, 5], [3, 5], [4, 7], [6, 9], [6, 9], [5, 7]].collect({arg x; interval.(x[0], x[1])});
var fm_f = [[2, 8], [2, 7], [2, 6], [3, 5], [3, 4], [4, 3], [6, 2], [6, 1], [5, 0]].collect({arg x; interval.(x[0], x[1])});
//1/[9, 9, 9, 27, 27, 81, 729, 729, 81];
var fm_a = 1/[2, 4, 2, 5, 5, 6, 7, 8, 8].collect({arg oct, i; interval.(i, oct)});
//tune.pow([-1, -2, -1, -2, -2, -3, -4, -5, -5]);//1/[3, 9, 3, 9, 9, 27, 81, 243, 243]/3;
var fm_t = 1/[2, 2, 4, 2, 2, 2, 1, 1, 0].collect({arg oct, i; interval.(i, oct)});
//1/[3, 3, 9, 3, 3, 3, 1/3, 1/3, 1];
var octave = [0, 1, 2, 1, 2, 3, 2, 3, 4];
// var octave = [0, 1, 2, 3, 3, 4, 4, 5, 5];
var am_f = fund*[[0, -1], [1, -1], [2, -1], [0, 0], [1, 0], [0, 0], [1, 0], [0, 0], [1, 0]].collect({arg x; interval.(x[0], x[1])});
var am_t = [0,1,2,1,1,1,1,1,1];//1/[2, 4, 2, 5, 5, 6, 7, 8, 8].collect({arg oct, i; interval.(i, oct)});
var total_secs = 12600;

p.clear;
~preout.ar(2);
// ~out.ar(2);
~out = {Limiter.ar(LeakDC.ar(~preout.ar))};
~out.play;

~ifund = {DC.kr(1)};
// ~ifund = {SinOsc.kr(1/12600, -0.5pi, 1/3, 1)};
// ~ifund = {SinOsc.kr(9, 0, SinOsc.kr(1/total_secs, -0.5pi, 1/2, 1/2)/81, 0) + SinOsc.kr(1/total_secs, -0.25pi, 2/3, 4/3)};

// ~rate = {DC.kr(r)};
~rate = {f[\sincosc].(1/total_secs, 8, fixdc:1, iphase:1)*11/3+1*r};
// ~rate = {f[\sincosc].(1/total_secs, 8, fixdc:1, iphase:1)-f[\sincosc].(1/total_secs, 8, fixdc:1, iphase:0)*0.965+1*r};

~preout = {
    var chan_pairs = Array.fill(n, { arg i;
        var timbre = SinOsc.kr(~rate.ar[0]*r_partials[i], phase[i]*2pi, 1/2, 1/2).pow(3)*partials[i];
        var amp = SinOsc.kr(r_amp[i]*~rate.ar[0], -0.5pi, 1/2, 1/2).pow(i/3+2);
        var freq = ~ifund.kr[0]*interval.(i, octave[i])*fund;
        var fm = 2.pow(f[\sincosci2].(freq*fm_f[i], timbre*fm_t[i])*amp*fm_a[i]);
        var am = f[\sincosci2].(am_f[i], am_t[i], fixdc:0)*amp/2 + 1-(amp/2);
        var ff = fm*freq;
        // (f[\sincosci2].(fm*freq, timbre, (timbre+1).sqrt/2)*amp*pi/2).sin*(2.pow(-1*i/4))
        [
            (f[\sincosci2].(ff, timbre, (timbre+1).sqrt/2)*amp*0.5pi*am).sin,
            f[\sincosci2].(ff*interval.(1, 5-octave[i]), 3)*amp*am,
            f[\sincosci2].(ff/fm.pow(0.75)*interval.(1, 4-octave[i]), 3)*amp*am
        ]*(2.pow(0-i/4))
    });

    //var chans = chan_pairs.flop[0][[0, 3, 4, 1, 5, 6, 2, 7, 8]];//* DC.kr([1, 0, 0, 1, 0, 0, 1, 0, 0]); //111100000: harsh, muddy. 000111100: beaut, dark. 100000111: eerie. 011011011: serene
    //var chans2 = chan_pairs.flop[1][[6, 4, 7, 8, 3, 5]];
    //var chans3 = chan_pairs.flop[2][[1, 3, 2, 4, 0]];
    //var subs = chan_pairs.flop[0][[0, 1]];

    var chans = chan_pairs.flop[0][[0, 3, 4, 1, 5, 6, 2, 7, 8]];
    var chans2 = chan_pairs.flop[1][[6, 4, 7, 8, 3, 5]];
    var chans3 = chan_pairs.flop[2][[1, 3, 2, 4, 0]];
    var subs = chan_pairs.flop[0][[0, 1]];


    // chans = chans[[3, 2, 5, 0, 7, 1, 4, 6, 8]];
    // chans = chans[[0, 3, 5, 1, 7, 4, 6, 2, 8]];

    // var foll = Amplitude.ar(chans, 1/6, 1/6);
    // var foll_norm = (foll*foll).sum/foll.sum.max(1e-12);

    0

    // + Splay.ar(chans)

    + (Splay.arFill(2, { arg i;
        var weights = SinOsc.ar(~rate.ar[0]*6, Array.fill(n, {arg j; i/2+(j/n)})*2pi, 1/2, 1/2).pow(3);
        (2pi/weights.sum.sqrt*(chans*weights).sum).sin
    }, 2/3)/6)

    + (Splay.ar(
        SplayAz.ar(9, chans2, 1/2, center: 4, orientation: 0) + 1
        * (SplayAz.ar(9, chans3, 1/2, center: 4, orientation: 0) + 1)
    - 1)/9).reverse
    + (0
        + (Splay.ar(chans2, 1/3)/9)
        + (Splay.ar(chans3, 1/9)/9)
        * Mix.new(3.pow(-1*subs)/2)
    )

    + (Splay.arFill(2, { arg i;
        var weights = SinOsc.ar(~rate.ar[0]*6, Array.fill(n, {arg j; i/2+(j/n)+(1/8)})*2pi, 1/2, 1/2)**2;
        // (chans*weights+1-(foll.max(0).sqrt*weights)).product*foll_norm
        (chans*weights+1).product-1
    }, 7/9).reverse/3)

};

);


s.quit

(
var tune = 3;
var interval = { arg degree, octave;
    2.pow(tune.pow(degree).log2%1+octave)
};
interval.(4, -1)
)


(

{[
    f[\sincosc].(10, 8),
    f[\sincosc].(10, 9),
    f[\sincosci].(10, 8.5),
    f[\sincosci2].(10, 8.5)
]}.plot(3/20)
)

({
    f[\sincosc].(10, 8, fixdc:1, iphase:1)-f[\sincosc].(10, 8, fixdc:1, iphase:0)*0.965+1
}.plot(3/20)
)

2*3*5*7/60

{ SplayAz.ar(6, [SinOsc.ar, Saw.ar(800)], spread: MouseX.kr(0, 1).poll, orientation: 0, width:2)}.scope;