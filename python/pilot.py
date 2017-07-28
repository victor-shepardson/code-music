import time
import argparse
import numpy as np

from numba import jit

import pyaudio
from pyaudio import get_format_from_width, paFloat32, paContinue

@jit(nopython=True)
def get(a, idx):
    return a[idx%len(a)]

@jit(nopython=True)
def getl(a, idx):
    below = a[int(idx)%len(a)]
    above = a[int(idx+1)%len(a)]
    m = (idx%1)
    return below*(1-m) + above*m

@jit(nopython=True)
def reverse(a):
    r = np.empty_like(a)
    for i,x in enumerate(a):
        r[-1-i] = x
    return r

@jit(nopython=True)
def rot(a,n=1):
    r = np.empty_like(a)
    for i,x in enumerate(a):
        r[(i-n)%len(a)] = x
    return r

@jit(nopython=True)
def _step(a, idx):
    idx -= 1
    k = 8
    m = 1e0*np.ones(a.shape[1])
    alpha = -1
    x = np.zeros(a.shape[1])
    for j in range(k):
        y = getl(a, idx-1)
        d = (getl(a, idx)-getl(a, idx-2))/2
        d = rot(d,1)
        x = np.tanh(y+alpha*d)
        # x = reverse(x)
        idx -= 2**(5*(1+x.mean()))/k
    p = np.arange(a.shape[1])/2*np.pi
    m *= (np.sin(2*np.pi*x)-1)**4#2**(4*(np.sin(2*np.pi*x)-1))
    x = rot(x)
    y = getl(a, idx)
    y = (y+getl(a, idx-1)+getl(a, idx-2))/3
    return (1-m)*y + m*np.cos(2*np.pi*x)

@jit(nopython=True)
def _stepn(a, idx, n):
    data = np.empty((n, a.shape[1]), dtype=np.float32)
    w_start = 0
    r_start = idx
    for _ in range(n):
        v = _step(a, idx)
        a[idx] = v
        idx += 1
        if idx==len(a):
            seg_len = len(a)-r_start
            data[w_start:w_start+seg_len] = a[r_start:]
            w_start += seg_len
            idx = r_start = 0
    data[w_start:] = a[r_start:idx]
    return idx, data

class synth(object):
    def __init__(self, args):
        self.nchannels = 2
        self.nsamps = 1024
        self.samples = 1e-1*(np.random.rand(self.nsamps, self.nchannels)*2-1)
        self.idx = 0

    def cleanup(self):
        pass

    # def step(self):
    #     self.samples.append(self.samples[0])
    #     self.samples.pop(0)

    def callback(self, in_data, frame_count, time_info, status):
        # data = np.array(
        #     self.samples[-frame_count:], dtype=np.float32
        # ).flatten()
        # return (data, paContinue)
        self.idx, data = _stepn(self.samples, self.idx, frame_count)
        return(data, paContinue)

    def get_stream(self, pa, sr):
        return pa.open(
            format=paFloat32,
            channels=self.nchannels,
            rate=sr,
            output=True,
            stream_callback=lambda *args: self.callback(*args)
        )

if __name__=='__main__':
    pa = pyaudio.PyAudio()
    parser = argparse.ArgumentParser(description='Pilot Oscillator')
    # parser.add_argument('filename')
    parser.add_argument('--sr', '-s', type=int, default=48000)
    args = parser.parse_args()
    s = synth(args)
    stream = s.get_stream(pa, args.sr)
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
