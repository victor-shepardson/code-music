(
// v-deep frequency modulation of h-wide sine wave clusters
~wiggle = {|in, amt=0.001, rate=1, h=4, v=2, hratio=0.125pi, hdecay=0.5, vratio=32, shape=1|
	var norm = Array.fill(h, {|i| hdecay**i}).sum,
	cluster = {|r, m| Mix.fill(h, {|i|
		SinOsc.ar(r*(hratio**i)*(2**m),0,hdecay**i)
	})/norm},
	wave = 0, z = 0;
	for (0,v-1,{ |i|
		wave = cluster.(rate*(vratio**(i-v+1)), wave*shape);
	});
	DelayC.ar(in, 3*amt, (wave+1)*amt/2+(SampleDur.ir*4))
};

// nice sounding fader with a linearish control
~fader = {|in, x|
	var xc = Clip.kr(x),
	hp = HPF.ar(in, 2**(0-xc*4)*300),
	lp = LPF.ar(hp, 2**(xc*6)*300);
	xc*lp
};

~tanh = {|in, drive=1|
	2/(1+exp(0-drive*in))-1
};
)

// ============= test ===============

(
{Splay.ar([
	~wiggle.(Mix.new(SinOscFB.ar(110*[1,1.333,1.5,2], 0.5)),
		amt:0.001, rate:3, shape:1, v:2, h:4)
	*0.2])}.play
)

(
{Splay.ar([
	~wiggle.(Mix.new(SinOscFB.ar(220*[1,1.333,1.5,2], 0.5)),
		amt:0.03*SinOsc.ar(0.07,0,1,2), rate:1.5, shape:4, v:3, h:4)
	*0.1])}.play
)

s.boot
s.quit