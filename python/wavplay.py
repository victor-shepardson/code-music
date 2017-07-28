"""PyAudio Example: Play a wave file.

Crude playback rate modulation with scipy.
"""

import pyaudio
from pyaudio import paFloat32, paInt32, paInt24, \
    paInt16, paInt8, paUInt8, get_format_from_width
import wave
import time
import argparse
import numpy as np
import scipy.signal

pa2np = {
    paFloat32: np.float32,
    paInt32: np.int32,
    paInt24: None,
    paInt16: np.int16,
    paInt8: np.int8,
    paUInt8: np.uint8,
}
def get_dtype_from_width(w):
    return pa2np[get_format_from_width(w)]

class synth(object):
    def __init__(self, args):
        self.rate = args.rate
        self.wf = wave.open(args.filename, 'rb')
        (self.nchannels, self.sampwidth, self.framerate, self.nframes, _, _
            ) = self.wf.getparams()

    def cleanup(self):
        self.wf.close()

    def callback(self, in_data, frame_count, time_info, status):
        n = int(frame_count*self.rate)
        data = np.frombuffer(
            self.wf.readframes(n),
            dtype=get_dtype_from_width(self.sampwidth)
            ).reshape(-1, self.nchannels) * 256**-self.sampwidth

        if len(data)>0:
            if self.rate>1:
                data = scipy.signal.resample(data, frame_count)
            elif self.rate<1:
                data = scipy.interpolate.interp1d(
                    np.linspace(0,1,n), data, axis=0
                    )(np.linspace(0,1,frame_count))

        data = data.astype(np.float32).flatten()
        return (data, pyaudio.paContinue)

    def get_stream(self, pa):
        return pa.open(
            format=paFloat32,
            channels=self.nchannels,
            rate=self.framerate,
            output=True,
            stream_callback=lambda *args: self.callback(*args)
        )

if __name__=='__main__':
    pa = pyaudio.PyAudio()
    parser = argparse.ArgumentParser(description='Pyaudio sample player')
    parser.add_argument('filename')
    parser.add_argument('--rate', '-r', type=float, default=1.0)
    args = parser.parse_args()
    s = synth(args)
    stream = s.get_stream(pa)
    try:
        stream.start_stream()
        while stream.is_active():
            time.sleep(0.1)
    except KeyboardInterrupt as e:
        print(e)
    except Exception:
        raise
    finally:
        stream.stop_stream()
        stream.close()
        s.cleanup()
        pa.terminate()
