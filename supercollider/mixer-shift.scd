(
s.options.memSize = 500000;
s.options.numAudioBusChannels = 512;
s.options.numInputBusChannels = 2;
s.options.numOutputBusChannels = 4;

s.boot
)

s.quit

s.queryAllNodes

p = ProxySpace.push(s);

// ~proxy.set(\param, value)
// ~proxy.xset(\param, value)
// ~proxy.map(\param, ~controlproxy)
// ~proxy.xmap(\param, ~controlproxy)

(
p.clear;
~in.ar(2);
~preout.ar(2);
~out.ar(2);
~aux.ar(2);
~out.play;
~aux.play(2);

~in = {SoundIn.ar([0,1])};
// ~a = {Amplitude.ar(~in.ar).pow(0.25)};
~a = {Amplitude.ar(~in.ar).pow(2.0)};

~f = {ZeroCrossing.ar(~in.ar)};
// ~f = {Slew.ar(ZeroCrossing.ar(~in.ar), 100, 100)};
// ~f = {2.pow(Slew.ar((ZeroCrossing.ar(~in.ar)+1).log2-1, ~a.ar*1, ~a.ar*1))};
~f = {2.pow(Slew.ar((ZeroCrossing.ar(~in.ar)+1).log2-1, ~a.ar*10000, ~a.ar*10000))};

// ~i = {~f.ar[1] - ~f.ar[0] / ~f.ar[0]};
// ~i = {ArrayMax.ar(~f.ar)[0] - ArrayMin.ar(~f.ar)[0] / ArrayMin.ar(~f.ar)[0]};
~i = {ArrayMax.ar(~f.ar)[0] / ArrayMin.ar(~f.ar)[0]};

// f = 55*[1, 3, 6, 8];
// f = 55*[1, 2, 3, 4];
// f = 55*[1, 2, 4, 8];
f = 55*[1, ~i, ~i*~i, ~i*~i*~i];
// f = 55*[1, ~i*~i, ~i*~i*~i*~i];

// ~preout = ~in;
~preout = {Mix.fill(f.size, {|i| 1.5.pow(-1*i)*FreqShift.ar(~in.ar, f[i]-~f.ar)})};

~verb = {GVerb.ar(Mix.new(~preout.ar),
		roomsize:50, revtime:5, damping:0.4, spread:0.9,
		earlyreflevel: 0.0, drylevel: 0
)};

// ~preaux = ~in;
// ~preaux = ~preout;
~preaux = {~preout.ar.reverse};
// ~preaux = ~preout+{FreqShift.ar(~in.ar, ~f.ar.log2-4 / 8)};
// ~preaux = ~preout+{FreqShift.ar(~in.ar, (~f.ar.log2*2*pi).cos+1 * 0.3)};
// ~preaux = {~preout.ar + FreqShift.ar(~in.ar, -1*(~f.ar/~f0[0][3]).sin)*0.3};
// ~preaux = {FreqShift.ar(~in.ar, 0.3)};
// ~preaux = ~verb;

~aux = {0.95*Limiter.ar(0.2*~preaux.ar)};
// ~out = {0.95*Limiter.ar(LeakDC.ar(~preout.ar))};
~out = {0.95*Limiter.ar(LeakDC.ar(~verb.ar*0.1+~preout.ar))};

// ~debug = {Poll.kr(Impulse.kr(10), [~a.ar, ~i.ar])}
)

~in.scope
~env.scope
~out.scope
~aux.scope
~i.scope