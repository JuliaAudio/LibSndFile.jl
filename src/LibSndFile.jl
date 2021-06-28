module LibSndFile

import SampledSignals
using SampledSignals: SampleSource, SampleSink, SampleBuf
using SampledSignals: PCM16Sample, PCM32Sample
using SampledSignals: nframes, nchannels, samplerate
using FileIO: File, Stream, filename, stream
using FileIO: add_format, add_loader, add_saver, @format_str
using Printf: @printf
using LinearAlgebra: transpose!
using libsndfile_jll: libsndfile

const supported_formats = (format"WAV", format"FLAC", format"OGG")

include("libsndfile_h.jl")
include("lengthIO.jl")
include("sourcesink.jl")
include("loadsave.jl")
include("readwrite.jl")

end # module LibSndFile
