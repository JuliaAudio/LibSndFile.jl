# precompile is now the default
VERSION < v"0.7.0-rc2" && __precompile__()

module LibSndFile

import SampledSignals
using SampledSignals: SampleSource, SampleSink, SampleBuf
using SampledSignals: PCM16Sample, PCM32Sample
using SampledSignals: nframes, nchannels, samplerate
using FileIO: File, Stream, filename, stream
using FileIO: add_format, add_loader, add_saver, @format_str
if VERSION >= v"0.7-"
    using Printf: @printf
    using LinearAlgebra: transpose!
else
    using Compat: Cvoid, @cfunction, @warn
end

const supported_formats = (format"WAV", format"FLAC", format"OGG")

include("libsndfile_h.jl")
include("lengthIO.jl")
include("sourcesink.jl")
include("loadsave.jl")
include("readwrite.jl")

function __init__()
    # ogg currently not in the registry
    add_format(format"OGG", "OggS", [".ogg", ".oga"], [:LibSndFile])
    for fmt in supported_formats
        add_loader(fmt, :LibSndFile)
        add_saver(fmt, :LibSndFile)
    end
end

depsjl = joinpath(@__DIR__, "..", "deps", "deps.jl")
if isfile(depsjl)
    include(depsjl)
else
    error("LibSndFile not properly installed. Please run Pkg.build(\"LibSndFile\")")
end

end # module LibSndFile
