# precompile is now the default
VERSION < v"0.7.0-rc2" && __precompile__()

module LibSndFile

# TODO: only pull in the names that we need
using SampledSignals
# TODO: switch to qualified method extension instead of importing here
import SampledSignals: nchannels, nframes, samplerate, unsafe_read!, unsafe_write
using FileIO: File, Stream, filename, stream
using FileIO: add_format, add_loader, add_saver, @format_str
if VERSION >= v"0.7-"
    using Printf: @printf
    using LinearAlgebra: transpose!
else
    using Compat: Cvoid, @cfunction
end

include("libsndfile_h.jl")

const supported_formats = (format"WAV", format"FLAC", format"OGG")

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

# wrapper around an arbitrary IO stream that also includes its length, which
# libsndfile requires. Needs to be mutable so it's stored as a reference and
# we can pass a pointer into the C code
mutable struct LengthIO{T<:IO} <: IO
    io::T
    length::Int
end

Base.length(io::LengthIO) = io.length
for f in (:read, :read!, :write, :readbytes!,
          :unsafe_read, :unsafe_write,
          :seek, :seekstart, :seekend, :position, :skip,
          :close)
    @eval @inline Base.$f(io::LengthIO, args...) = $f(io.io, args...)
end
# needed for method ambiguity resolution
Base.readbytes!(io::LengthIO, arr::AbstractArray{UInt8,N} where N) = readbytes!(io.io, arr)

"""
    inferlen(io)

Try to infer the length of `io` in bytes
"""
inferlen(io::IOBuffer) = io.size
inferlen(io::IOStream) = filesize(io)
function inferlen(io::Stream)
    fname = filename(io)
    if fname !== nothing
        filesize(fname)
    else
        inferlen(stream(io))
    end
end
inferlen(io) = throw(ArgumentError("file length could not be inferred and must be passed explicitly"))

mutable struct SndFileSink{T} <: SampleSink
    src::Union{String, Nothing}
    filePtr::Ptr{Cvoid}
    sfinfo::SF_INFO
    nframes::Int64
    writebuf::Array{T, 2}
end

function SndFileSink(path, filePtr, sfinfo, bufsize=4096)
    T = fmt_to_type(sfinfo.format)
    writebuf = zeros(T, sfinfo.channels, bufsize)
    SndFileSink(path, filePtr, sfinfo, 0, writebuf)
end

nchannels(sink::SndFileSink) = Int(sink.sfinfo.channels)
samplerate(sink::SndFileSink) = sink.sfinfo.samplerate
nframes(sink::SndFileSink) = sink.nframes
Base.eltype(sink::SndFileSink) = fmt_to_type(sink.sfinfo.format)

# src is either a string representing the path to the file, or an IO stream
mutable struct SndFileSource{T, S<:Union{String, LengthIO}} <: SampleSource
    src::S
    filePtr::Ptr{Cvoid}
    sfinfo::SF_INFO
    pos::Int64
    readbuf::Array{T, 2}
end

function SndFileSource(src, filePtr, sfinfo, bufsize=4096)
    T = fmt_to_type(sfinfo.format)
    readbuf = zeros(T, sfinfo.channels, bufsize)

    SndFileSource(src, filePtr, sfinfo, 1, readbuf)
end

nchannels(source::SndFileSource) = Int(source.sfinfo.channels)
samplerate(source::SndFileSource) = source.sfinfo.samplerate
nframes(source::SndFileSource) = source.sfinfo.frames
Base.eltype(source::SndFileSource{T}) where T = T

function Base.show(io::IO, s::Union{SndFileSource, SndFileSink})
    println(io, typeof(s))
    println(io, "  path: \"$(s.src)\"")
    println(io, "  channels: ", nchannels(s))
    println(io, "  samplerate: ", samplerate(s), "Hz")
    # SndFileSinks don't have a position and we're always at the end
    pos = isa(s, SndFileSource) ? s.pos-1 : nframes(s)
    postime = float((pos)/samplerate(s))
    endtime = float((nframes(s))/samplerate(s))
    println(io, "  position: $(pos) of $(nframes(s)) frames")
    @printf(io, "            %0.2f of %0.2f seconds", postime, endtime)
end

function loadstreaming(src::File)
    sfinfo = SF_INFO()
    fname = filename(src)
    # sf_open fills in sfinfo
    filePtr = sf_open(fname, SFM_READ, sfinfo)

    SndFileSource(fname, filePtr, sfinfo)
end

function loadstreaming(src::Stream, filelen=inferlen(src))
    sfinfo = SF_INFO()
    fname = filename(src)
    io = LengthIO(stream(src), filelen)
    # sf_open fills in sfinfo
    filePtr = sf_open(io, SFM_READ, sfinfo)

    SndFileSource(io, filePtr, sfinfo)
end

function Base.close(s::SndFileSource)
    sf_close(s.filePtr)
end

function unsafe_read!(source::SndFileSource, buf::Array, frameoffset, framecount)
    total = min(framecount, nframes(source) - source.pos + 1)
    nread = 0
    readbuf = source.readbuf
    while nread < total
        n = min(size(readbuf, 2), total - nread)
        nr = sf_readf(source.filePtr, readbuf, n)
        # the data comes in interleaved, so we need to transpose
        transpose!(view(buf, (1:nr) .+ frameoffset .+ nread, :),
                   view(readbuf, :, 1:nr))
        source.pos += nr
        nread += nr
        nr == n || break
    end

    nread
end

for T in (:File, :Stream), fmt in supported_formats
    @eval @inline load(src::$T{$fmt}, args...) = load_helper(src, args...)
end

function load_helper(src::Union{File, Stream}, args...)
    str = loadstreaming(src, args...)
    buf = try
        read(str)
    finally
        close(str)
    end

    buf
end

function savestreaming(path::File{T}, nchannels, samplerate, elemtype) where T
    sfinfo = SF_INFO()

    sfinfo.samplerate = samplerate
    sfinfo.channels = nchannels
    sfinfo.format = formatcode(T)
    # TODO: should we auto-convert 32-bit integer samples to 24-bit?
    if T == format"FLAC" && elemtype != PCM16Sample
        error("LibSndFile.jl: FLAC only supports 16-bit integer samples")
    end
    if T == format"OGG"
        sfinfo.format |= SF_FORMAT_VORBIS
    else
        sfinfo.format |= subformatcode(elemtype)
    end

    filePtr = ccall((:sf_open, libsndfile), Ptr{Cvoid},
                    (Ptr{UInt8}, Int32, Ref{SF_INFO}),
                    filename(path), SFM_WRITE, sfinfo)

    if filePtr == C_NULL
        errmsg = ccall((:sf_strerror, libsndfile), Ptr{UInt8}, (Ptr{Cvoid},), filePtr)
        error("LibSndFile.jl error while saving $path: ", unsafe_string(errmsg))
    end

    SndFileSink(filename(path), filePtr, sfinfo)
end

# returns the number of samples written
function unsafe_write(sink::SndFileSink, buf::Array, frameoffset, framecount)
    nwritten = 0
    writebuf = sink.writebuf
    while nwritten < framecount
        n = min(size(writebuf, 2), framecount - nwritten)
        # the data needs to be interleaved, so we need to transpose
        transpose!(view(writebuf, :, 1:n),
                   view(buf, (1:n) .+ frameoffset .+ nwritten, :))
        nw = sf_writef(sink.filePtr, writebuf, n)
        sink.nframes += nw
        nwritten += nw
        nw == n || break
    end

    nwritten
end

function Base.close(str::SndFileSink)
    err = ccall((:sf_close, libsndfile), Int32, (Ptr{Cvoid},), str.filePtr)
    if err != 0
        error("LibSndFile.jl error while saving $path: Failed to close file")
    end
end

for fmt in supported_formats
    @eval save(path::File{$fmt}, buf::SampleBuf) = save_helper(path, buf)
end

function save_helper(path::File, buf::SampleBuf)
    sfinfo = SF_INFO()
    stream = savestreaming(path, nchannels(buf), samplerate(buf), eltype(buf))

    try
        frameswritten = write(stream, buf)
        if frameswritten != nframes(buf)
            error("Only wrote $frameswritten frames, expected $(nframes(buf))")
        end
    finally
        # make sure we close the file even if something goes wrong
        close(stream)
    end

    nothing
end

"""
Wrappers for the family of sf_readf_* functions, which read the given number
of frames into the given array. Returns the number of frames read.
"""
function sf_readf end

sf_readf(filePtr, dest::Array{T}, nframes) where T <: Union{Int16, PCM16Sample} =
    ccall((:sf_readf_short, libsndfile), Int64,
        (Ptr{Cvoid}, Ptr{T}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{T}, nframes) where T <: Union{Int32, PCM32Sample} =
    ccall((:sf_readf_int, libsndfile), Int64,
        (Ptr{Cvoid}, Ptr{T}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{Float32}, nframes) =
    ccall((:sf_readf_float, libsndfile), Int64,
        (Ptr{Cvoid}, Ptr{Float32}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{Float64}, nframes) =
    ccall((:sf_readf_double, libsndfile), Int64,
        (Ptr{Cvoid}, Ptr{Float64}, Int64),
        filePtr, dest, nframes)

"""
Wrappers for the family of sf_writef_* functions, which write the given number
of frames into the given array. Returns the number of frames written.
"""
function sf_writef end

sf_writef(filePtr, src::Array{T}, nframes) where T <: Union{Int16, PCM16Sample} =
    ccall((:sf_writef_short, libsndfile), Int64,
                (Ptr{Cvoid}, Ptr{T}, Int64),
                filePtr, src, nframes)

sf_writef(filePtr, src::Array{T}, nframes) where T <: Union{Int32, PCM32Sample} =
    ccall((:sf_writef_int, libsndfile), Int64,
                (Ptr{Cvoid}, Ptr{T}, Int64),
                filePtr, src, nframes)

sf_writef(filePtr, src::Array{Float32}, nframes) =
    ccall((:sf_writef_float, libsndfile), Int64,
                (Ptr{Cvoid}, Ptr{Float32}, Int64),
                filePtr, src, nframes)

sf_writef(filePtr, src::Array{Float64}, nframes) =
    ccall((:sf_writef_double, libsndfile), Int64,
                (Ptr{Cvoid}, Ptr{Float64}, Int64),
                filePtr, src, nframes)

#
# function Base.seek(file::AudioFile, offset::Integer, whence::Integer)
#     new_offset = ccall((:sf_seek, libsndfile), Int64,
#         (Ptr{Cvoid}, Int64, Int32), file.filePtr, offset, whence)
#
#     if new_offset < 0
#         error("Could not seek to $(offset) in file")
#     end
#
#     new_offset
# end
#
# # Some convenience methods for easily navigating through a sound file
# Base.seek(file::AudioFile, offset::Integer) = seek(file, offset, SF_SEEK_SET)
# rewind(file::AudioFile) = seek(file, 0, SF_SEEK_SET)

end # module LibSndFile
