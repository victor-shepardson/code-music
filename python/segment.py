import sys, os

import numpy as np
from scipy.io import wavfile
from scipy.signal import stft

def usage():
    print("""Segment audio.
    
    args: filename.wav
    
    create new files filename/1.wav...filename/N.wav
    """)

def normalize(x):
    x -= x.mean(0)
    x /= x.std(0)

def to_mono(x):
    return x.sum(1)

#TODO
#TODO: coarse global segmentation w/ spectral properties
def segment(x, sr, block=512, overlap=2, min_proximity=0.3, verbose=True):
    """Segment audio.
    
    x: mono, normalized PCM audio
    sr: sample rate
    Return array of indices to split at.
    """
    noverlap = (block*(overlap-1)/overlap)
    fs, ts, spectra = stft(
        x, sr,
        window='nutall',
        nperseg=block, noverlap=noverlap,
        return_onesided=True,
        boundary='zeros'
    )
    # spectra is an (n_bins, n_windows) array
    mag, phase = np.absolute(spectra), np.angle(spectra)
    # to polar
    phase_diff, mag_diff = np.unwrap(np.diff(phase)), np.diff(mag)
    # absolute, normalized change in phase increment, mean over bins
    phase_score = np.abs(np.diff(phase_diff)/np.pi).mean(0)
    # rectified change in magnitude, mean over bins
    mag_score = np.max(mag_diff, 0).mean(0)[:-1]
    if verbose:
        print('phase_score mean: {}, std: {}'.format(phase_score.mean(), phase_score.std()))
        print('mag_score mean: {}, std: {}'.format(mag_score.mean(), mag_score.std()))
    # compute onset score
    onset_score = phase_score+mag_score
    # sort by scores
    idxs = np.argsort(onset_score)[::-1]
    split_ts = []
    # loop through, discarding any too close in time to one already seen
    for i in tqdm(idxs):
        # stupid brute force
        if np.abs(np.array(split_ts)-ts[i]).max() > min_proximity:
            split_ts.append(ts[i])
        # stop as some function of (number selected, audio length, difference criterion)
        if len(split_ts) >= ts[-1]/min_proximity or onset_score[i]<thresh:
            break
    sample_idxs = (np.array(split_ts)*sr).astype(np.int64)
    if verbose:
        print('{} indices selected'.format(len(sample_idxs)))
        print(sample_idxs)
    return sample_idxs

#TODO: local search for best split location based on waveform
#TODO: adaptive fade based on waveform properties at endpoints
def split_at(idxs, audio):
    """Split audio.
    
    idxs: np.int64 array of indices to split at
    audio: (nsamps, nchannels) array of PCM audio
    Return a list of audio arrays.
    """
    return np.split(audio, idxs)

#TODO: discard silent segments
#TODO: sort by centroid
def main():
    # load from wav
    try:
        fname = sys.argv[1]
    except Exception:
        usage()
        return
    sr, audio = wavfile.read(fname)
    # normalized mono version for feature extraction
    mono = to_mono(audio)
    normalize(mono)
    # segment
    idxs = segment(mono, sr)
    segments = split(idxs, audio)
    # write segments to wav
    for s in segments:
        wavfile.write(str(i)+'.wav', sr, s)

if __name__=='__main__':
    main()