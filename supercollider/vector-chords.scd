(
s.options.numWireBufs = 1024;
s.waitForBoot{
    var hosc = { arg osc, scale, tun, degree;
		// intervals between
		var tave = 1;
		var scaleabs = scale.collect{ |item|
			var last = tave;
			tave = tave * item;
			last
		}.postln;

        var sb = LocalBuf.newFrom(scaleabs);

        var degree_intervals, ws, fs;

		var coords = [-1, 0, 1];
		var kernel = { |dist| (dist.abs.clip(0,1)*pi).cos+1/2};

        // var coords = [-1, 0, 1, 2];
		// var kernel = { |dist| ((dist.abs/1.5).clip(0,1)*1pi).cos+1/2};

		// var coords = [-2, -1, 0, 1, 2];
		// var kernel = { |dist| (dist.abs.clip(0,2)*0.5pi).cos+1/2};

        var arr = [[degree]];

        var val = arr.round + coords;
        var mix = kernel.(arr - val);
        // k x 1 x ...
        // need to re-order these arrays based on the index.
		// so the active voices don't move
        // between oscillators, causing sudden phase shift.
        // not possible to actually reorder sclang arrays based on the signal of course
        // instead can use a binary mixing matrix
        // feel like there should be a nicer way to do this...
        var mm = (val % coords.size - [(0..coords.size-1)]).abs<=0; // abs<=, because == doesn't work on ugens (?)
        // k x k
        val = Mix(val*mm);
        mix = Mix(mix*mm);
        // k x ...

        degree_intervals = (
            Index.ar(sb, val % scale.size)
			* tave.pow((val / scale.size).floor)
        );

        fs = degree_intervals * [tun];

        fs.shape.postln;

        Mix(osc.(fs)*mix) / kernel.(coords).sum;
    };

	var scale = [
		5/4,
		6/5,
		5/4,
		3/5,
		11/9,
		14/11,
		8/7
	];
	var circ = [
		3/2,
		3/4
	];

    {
        // var sig = Blip.ar(66 + SinOsc.ar([1/4, 1/5]));
        // var sig = Blip.ar([33,66,90,99,132], 500);
        // var sig = hblip.(33, SinOsc.ar(0.1).range(0, 12), DC.ar(7.5));
        // var sig = hblip.(33, 2, SinOsc.ar(0.2).range(0,12));
        // var sig = hblip.([33,45,99], SinOsc.ar(0.0311).range(0, 8), SinOsc.ar(0.02).range(0,8));
        var vib = SinOsc.ar([1pi,2.sqrt,2]);
		var trem = 1-(vib*vib);
        var rate = 1/32;
        var rootr = 4;
        var degr = 9;
		// var sig = hosc.(
		// 	{ |x| Saw.ar(x)},
		// 	scale,
		// 	// [33,66,90,99],
		// 	99,
		// 	// 33+[0,0.3],
		// 	// [99,33,45]*2.pow(vib/400),
		// SinOsc.ar(rate/degr).range(0,degr));
        var thirdsosc = { |tun| hosc.(
			// { |x| Saw.ar(x)},
			// { |x| Blip.ar(x, 24)},
			// { |x| Blip.ar(x, 16) + Saw.ar(x) /2},
			{ |x| (Saw.ar(x/2)/4 + Blip.ar(x, 16) * 0.5pi).sin},
			// { |x| Blip.ar(x, 24).sin},
			scale,
			tun,
            SinOsc.ar(rate/degr).range(0-degr,degr))
		};
		var sig = hosc.(
			thirdsosc,
			circ,
			[33,99,45]*2.pow(vib/200),
			SinOsc.ar(rate/3/rootr).range(0-rootr,rootr)
		);
		// var sig = thirdsosc.(99);
		sig = sig/8 + Mix((
			BPF.ar([sig], [
				2.pow(SinOsc.ar(rate/[3,5,7]).range(8, 10)),
				2.pow(SinOsc.ar(rate/[8,11,13]).range(10, 11)),
			], 0.5)
			++ HPF.ar(sig, 4000, mul:2.pow(SinOsc.ar(rate/[16,17,18]).range(-5,-2)))
		) * trem
		);
		sig = BRF.ar(sig, 2200, 2);
		// sig = Formlet.ar(sig, 200, 1e-3, 10e-3) * (1e4 / SampleRate.ir);
        // sig = BRF.ar(sig, (1..4)*200+1700, 2);
        // sig = Integrator.ar(sig, 0.9);
		sig = Splay.ar(sig);
		// Limiter.ar(sig*0.2);
		(sig*0.2);
    }.play;
})


2.pow([2,3,4,5]/12)

15/11

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
