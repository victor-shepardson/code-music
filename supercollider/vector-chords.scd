//TODO: broadcast correctly

(
s.options.numWireBufs = 1024;
s.waitForBoot{
    // root moving by perfect 5ths (or 4ths)
    // degree moving by just diatonic 3rds

    //TODO: wrap vs no wrap
    // idea: write this as a composition of two 1d versions (using scale)
    // then the circle of fifths could be repeating +5th -4th
    // well would have to allow non-repeating scales expressed as intervals...
    // could convert one to the other just by taking cumprod of the scale,
    // and computing the corresponding tave from the scale
    var hblip = { arg tun, root, degree;
        var scale = [
            1,
            5/4,
            3/2,
            15/8,
            9/8,
            4/3, //27/10
            5/3, //27/8
        ];
/*        var scale = [
            1,
            5/4,
            3/2,
            15/8,
            9/4,
            8/3, //27/10
            10/3, //27/8
        ];*/
        // var scale = [
        //     1,
        //     5/4,
        //     3/2,
        //     17/9,
        //     9/4,
        //     8/3,
        //     10/3,
        // ];
        // var tave = 4; //octave, tritave etc
        // var scale = [
        //     1,
        //     9/8,
        //     5/4,
        //     4/3,
        //     3/2,
        //     5/3,
        //     17/9,
        // ];
        var tave = 2; //octave, tritave etc
        var sb = LocalBuf.newFrom(scale);
        var circ = 3/2; // circle of fifths, fourths etc

        var root_intervals, degree_intervals, ws, fs;

        // TODO: abstract out the kernel size / envelope shape

        // var coords = [-1, 0, 1];
        // var kernel = { |dist| 1 - dist.abs.clip(0,1)};
        // var kernel = { |dist| (dist.abs.clip(0,1)*pi).cos+1/2};
        // var coords = [-1, 0, 1, 2];
        var kernel = { |dist| ((dist.abs/1.5).clip(0,1)*1pi).cos+1/2};

        var coords = [-2, -1, 0, 1, 2];
        // var kernel = { |dist| (dist.abs.clip(0,2)*0.5pi).cos+1/2};


        var aroot = [[root]];
        var adegree = [[degree]];

        var rval = aroot.round + coords;
        var rmix = kernel.(aroot - rval);
        var dval = adegree.round + coords;
        var dmix = kernel.(adegree - dval);
        // k x 1 x ...
        // need to re-order these arrays based on the index so the active voices don't move
        // between oscillators, causing sudden phase shift,
        // not possible to actually reorder sclang arrays based on the signal of course
        // instead can use a binary mixing matrix
        // feel like there should be a nicer way to do this...
        var mm = (rval % coords.size - [(0..coords.size-1)]).abs<=0; // abs<=, because == doesn't work on ugens (?)
        // k x k
        rval = Mix(rval*mm);
        rmix = Mix(rmix*mm);
        // k x ...

        mm = (dval % coords.size - [(0..coords.size-1)]).abs<=0;
        dval = Mix(dval*mm);
        dmix = Mix(dmix*mm);

        root_intervals = circ.pow(rval);
        degree_intervals = (
            Index.ar(sb, dval % scale.size)
            // * tave.pow((dval / scale.size).floor)
        );

        // ws = rmix.sqrt * [dmix.sqrt];
        ws = rmix * [dmix];
        fs = root_intervals * [degree_intervals] * [[tun]];

        [ws.shape, fs.shape].postln;

        Mix((Saw.ar(fs)*ws).flatten) / kernel.(coords).sum;
    };

    {
        // var sig = Blip.ar(66 + SinOsc.ar([1/4, 1/5]));
        // var sig = Blip.ar([33,66,90,99,132], 500);
        // var sig = hblip.(33, SinOsc.ar(0.1).range(0, 12), DC.ar(7.5));
        // var sig = hblip.(33, 2, SinOsc.ar(0.2).range(0,12));
        // var sig = hblip.([33,45,99], SinOsc.ar(0.0311).range(0, 8), SinOsc.ar(0.02).range(0,8));
        var vib = SinOsc.ar([1pi,2.sqrt,2]);
        var vib2 = SinOsc.ar(9);
        var rate = 1;
        var rootr = 8;
        var degr = 8;
        var sig = hblip.(
            // [33,66,90,99],
            // 33,
            // 33+[0,0.3],
            [99,33,45]*2.pow(vib/400),
            SinOsc.ar(rate*0.01/rootr).range(0,rootr),
            SinOsc.ar(rate*0.1/degr).range(0,degr));
        sig = BRF.ar(sig, 1700, 2);
        // sig = BRF.ar(sig, (1..4)*200+1700, 2);
        // sig = Integrator.ar(sig, 0.9);
        sig = Splay.ar(sig);
        // Limiter.ar(sig*0.2);
        (sig*0.2);
    }.play;
})

1.5**8 * 66

1.3.frac
[9/8, 2.pow(2/12)]
[5/4, 2.pow(4/12)]
[4/3, 2.pow(5/12)]
[3/2, 2.pow(7/12)]
[5/3, 2.pow(9/12)]
[17/9, 2.pow(11/12)]
// [81/32, 2.pow(11/12)]

(30/7).floor
