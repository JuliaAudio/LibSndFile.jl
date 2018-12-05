LibSndFile.jl
=============
[![Build Status](https://travis-ci.org/JuliaAudio/LibSndFile.jl.svg?branch=master)](https://travis-ci.org/JuliaAudio/LibSndFile.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/1wdo413vf375i1vr/branch/master?svg=true)](https://ci.appveyor.com/project/ssfrr/libsndfile-jl/branch/master)
[![codecov.io](https://codecov.io/github/JuliaAudio/LibSndFile.jl/coverage.svg?branch=master)](https://codecov.io/github/JuliaAudio/LibSndFile.jl?branch=master)

LibSndFile.jl is a wrapper for [libsndfile](http://www.mega-nerd.com/libsndfile/), and supports a wide variety of file and sample formats. The package uses the [FileIO](https://github.com/JuliaIO/FileIO.jl) `load` and `save` interface to automatically figure out the file type of the file to be opened, and the file contents are represented as a `SampleBuf`. For streaming I/O we support FileIO's `loadstreaming` and `savestreaming` functions as well. The results are represented as `SampleSource` (for reading), or `SampleSink` (for writing) subtypes. These buffer and stream types are defined in the [SampledSignals](https://github.com/JuliaAudio/SampledSignals.jl) package.

Note that the `load`/`save`/etc. interface is exported from `FileIO`, and `LibSndFile` registers itself when the loaded, so you should bring in both packages. LibSndFile doesn't export any of its own names.

```julia
julia> using FileIO: load, save, loadstreaming, savestreaming
julia> import LibSndFile
julia> load("audiofile.wav")
2938384-frame, 1-channel SampleBuf{FixedPointNumbers.Fixed{Int16,15}, 2}
66.63002267573697s sampled at 44100.0Hz
▆▅▆▆▆▆▆▅▆▆▆▇▇▇▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▇▆▆▆▆▆▇▆▇▆▇▆▆▆▅▆▆▆▆▆▆▅▆▆▅▆▅▆▆▇▇▇▇▆▆▆▆▆▆▇▆▆▆▆▆▆▆▇▆▇▂
```

## Examples

**Read ogg file, write first 1024 samples of the first channel to new wav file**
```julia
x = load("myfile.ogg")
save("myfile_short.wav", x[1:1024])
```

**Read file, write the first second of all channels to a new file**
```julia
x = load("myfile.ogg")
save("myfile_short.wav", x[0s..1s, :])
```

**Read stereo file, write mono mix**
```julia
x = load("myfile.wav")
save("myfile_mono.wav", x[:, 1] + x[:, 2])
```

**Plot the left channel**
```julia
x = load("myfile.wav")
plot(x[:, 1]) # plots with samples on the x axis
plot(domain(x), x[:, 1]) # plots with time on the x axis
```

**Plot the spectrum of the left channel**
```julia
x = load("myfile.wav")
f = fft(x) # returns a FrequencySampleBuf
plot(domain(x), x[:, 1]) # plots with frequency on the x axis
```

**Load a long file as a stream and plot the left channel from 2s to 3s**
```julia
s = loadstream("myfile.ogg")
x = read(s, 4s)[2s..3s, 1]
close(s)
plot(domain(x), x)
```

**To handle closing the file automatically (including in the case of unexpected exceptions), we support the `do` block syntax**

```julia
data = loadstream("data/never_gonna_give_you_up.ogg") do s
    readall(f)
end
```

## Supported Formats

See the [libsndfile](http://www.mega-nerd.com/libsndfile/) homepage for details, but in summary it supports reading and writing:

* Microsoft WAV
* Ogg/Vorbis
* FLAC
* SGI / Apple AIFF / AIFC
* RAW
* Sound Designer II SD2
* Sun / DEC / NeXT AU / SND
* Paris Audio File (PAF)
* Commodore Amiga IFF / SVX
* Sphere Nist WAV
* IRCAM SF
* Creative VOC
* Soundforge W64
* GNU Octave 2.0 MAT4
* GNU Octave 2.1 MAT5
* Portable Voice Format PVF
* Fasttracker 2 XI
* HMM Tool Kit HTK
* Apple CAF

Note not all file formats support all samplerates and bit depths. Currently LibSndFile.jl supports WAV, Ogg Vorbis, and FLAC files. Please file an issue if support for other formats would be useful.

## Related Packages

* [SampledSignals.jl](https://github.com/JuliaAudio/SampledSignals.jl) provides the basic stream and buffer types used by this package.
* [MP3.jl](https://github.com/JuliaAudio/MP3.jl) supports reading and writing MP3 files
* [WAV.jl](https://github.com/dancasimiro/WAV.jl) is a pure-julia package supporting the WAV file format.
* [Opus.jl](https://github.com/staticfloat/Opus.jl) wraps `libopus` and allows you to read and write Opus audio.
* [PortAudio.jl](https://github.com/JuliaAudio/PortAudio.jl) can be used to interface with your sound card to record and play audio.


## A Note on Licensing

libsndfile is [licensed](http://www.mega-nerd.com/libsndfile/#Licensing) under the LGPL, which is very permissive providing that libsndfile is dynamically linked. LibSndFile.jl is licensed under the MIT license, allowing you to statically compile the wrapper into your Julia application. Remember that you must still abide by the terms of the libsndfile license when using this wrapper, in terms of whether libsndfile is statically or dynamically linked.

Note that this is to the best of my understanding, but I am not an attorney and this should not be considered legal advice.
