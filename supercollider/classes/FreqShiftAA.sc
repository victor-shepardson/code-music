FreqShiftAA {
    *ar { arg in, freq=0.0, phase=0.0, mul=1.0, add=0.0;
        var hcutoff = (SampleRate.ir/2 - freq.max(0))/2;
        var lcutoff = ((0.0 - freq.min(0))*2).max(20);
        ^FreqShift.ar(BHiPass4.ar(BLowPass4.ar(in, hcutoff), lcutoff), freq, phase, mul, add);
    }
}