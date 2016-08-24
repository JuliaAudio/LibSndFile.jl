__precompile__()

module LibSndFile

using Compat
# we should be able to remove this and rename to String when we drop 0.4 support
import Compat: UTF8String

using SampledSignals
import SampledSignals: nchannels, nframes, samplerate, unsafe_read!, unsafe_write
using FileIO
import FileIO: load, save
using FixedPointNumbers
using SIUnits

# TODO: move these into FileIO.jl
export loadstream, savestream

# Re-export from FileIO
export load, save

typealias PCM16Sample Fixed{Int16, 15}
typealias PCM32Sample Fixed{Int32, 31}

function __init__()
    # this needs to be run when the module is loaded at run-time, even if
    # the module is precompiled.
    del_format(format"WAV")
    add_format(format"WAV", detectwav, ".wav", [:LibSndFile])
    del_format(format"FLAC")
    add_format(format"FLAC", "fLaC", ".flac", [:LibSndFile])
    add_format(format"OGG", "OggS", [".ogg", ".oga"], [:LibSndFile])
end


include("formats.jl")
include(Pkg.dir("LibSndFile", "deps", "deps.jl"))

# const SF_SEEK_SET = 0
# const SF_SEEK_CUR = 1
# const SF_SEEK_END = 2

const SFM_READ = Int32(0x10)
const SFM_WRITE = Int32(0x20)

formatcode(::Type{format"WAV"}) = SF_FORMAT_WAV
formatcode(::Type{format"FLAC"}) = SF_FORMAT_FLAC
formatcode(::Type{format"OGG"}) = SF_FORMAT_OGG

subformatcode(::Type{PCM16Sample}) = SF_FORMAT_PCM_16
subformatcode(::Type{PCM32Sample}) = SF_FORMAT_PCM_32
subformatcode(::Type{Float32}) = SF_FORMAT_FLOAT
subformatcode(::Type{Float64}) = SF_FORMAT_DOUBLE


# WAV is a subtype of RIFF, as is AVI
function detectwav(io)
    seekstart(io)
    magic = UTF8String(read(io, UInt8, 4))
    magic == "RIFF" || return false
    seek(io, 8)
    submagic = UTF8String(read(io, UInt8, 4))

    submagic == "WAVE"
end

"""Take a LibSndFile format code and return a suitable sample type"""
function fmt_to_type(fmt)
    mapping = Dict{UInt32, Type}(
        SF_FORMAT_PCM_S8 => PCM16Sample,
        SF_FORMAT_PCM_U8 => PCM16Sample,
        SF_FORMAT_PCM_16 => PCM16Sample,
        SF_FORMAT_PCM_24 => PCM32Sample,
        SF_FORMAT_PCM_32 => PCM32Sample,
        SF_FORMAT_FLOAT => Float32,
        SF_FORMAT_DOUBLE => Float64,
        SF_FORMAT_VORBIS => Float32,
    )

    masked = fmt & SF_FORMAT_SUBMASK
    masked in keys(mapping) || error("Format code $masked not recognized by LibSndFile.jl")

    mapping[masked]
end


type SF_INFO
    frames::Int64
    samplerate::Int32
    channels::Int32
    format::Int32
    sections::Int32
    seekable::Int32
end

type SndFileSink <: SampleSink
    path::UTF8String
    filePtr::Ptr{Void}
    sfinfo::SF_INFO
    nframes::Int64

    SndFileSink(path, filePtr, sfinfo) = new(path, filePtr, sfinfo, 0)
end

nchannels(sink::SndFileSink) = Int(sink.sfinfo.channels)
samplerate(sink::SndFileSink) = quantity(Int, Hz)(sink.sfinfo.samplerate)
nframes(sink::SndFileSink) = sink.nframes
Base.eltype(sink::SndFileSink) = fmt_to_type(sink.sfinfo.format)

type SndFileSource{T} <: SampleSource
    path::UTF8String
    filePtr::Ptr{Void}
    sfinfo::SF_INFO
    pos::Int64
    readbuf::Array{T, 2}
    transbuf::Array{T, 2}
end

function SndFileSource(path, filePtr, sfinfo, bufsize=4096)
    T = fmt_to_type(sfinfo.format)
    readbuf = Array(T, sfinfo.channels, bufsize)
    transbuf = Array(T, bufsize, sfinfo.channels)

    SndFileSource(path, filePtr, sfinfo, 1, readbuf, transbuf)
end

nchannels(source::SndFileSource) = Int(source.sfinfo.channels)
samplerate(source::SndFileSource) = quantity(Int, Hz)(source.sfinfo.samplerate)
nframes(source::SndFileSource) = source.sfinfo.frames
Base.eltype{T}(source::SndFileSource{T}) = T

function Base.show(io::IO, s::Union{SndFileSource, SndFileSink})
    println(io, typeof(s))
    println(io, "  path: \"$(s.path)\"")
    println(io, "  channels: ", nchannels(s))
    println(io, "  samplerate: ", samplerate(s))
    # SndFileSinks don't have a position and we're always at the end
    pos = isa(s, SndFileSource) ? s.pos-1 : nframes(s)
    postime = float((pos)/samplerate(s))
    endtime = float((nframes(s))/samplerate(s))
    println(io, "  position: $(pos) of $(nframes(s)) frames")
    @printf(io, "            %0.2f of %0.2f seconds", postime, endtime)
end

loadstream(path::AbstractString, args...; kwargs...) =
    loadstream(query(path), args...; kwargs...)

function loadstream(f::Function, args...)
    str = loadstream(args...)
    try
        f(str)
    finally
        close(str)
    end
end

function loadstream(path::File)
    sfinfo = SF_INFO(0, 0, 0, 0, 0, 0)

    filePtr = ccall((:sf_open, libsndfile), Ptr{Void},
                    (Ptr{UInt8}, Int32, Ptr{SF_INFO}),
                    filename(path), SFM_READ, &sfinfo)

    if filePtr == C_NULL
        errmsg = ccall((:sf_strerror, libsndfile), Ptr{UInt8}, (Ptr{Void},), filePtr)
        error("LibSndFile.jl error while loading $path: ", unsafe_string(errmsg))
    end

    SndFileSource(filename(path), filePtr, sfinfo)
end

function Base.close(s::SndFileSource)
    err = ccall((:sf_close, libsndfile), Int32, (Ptr{Void},), s.filePtr)
    if err != 0
        error("LibSndFile.jl error: Failed to close file")
    end
end

function unsafe_read!(source::SndFileSource, buf::SampleBuf)
    total = min(nframes(buf), nframes(source) - source.pos + 1)
    nread = 0
    readbuf = source.readbuf
    transbuf = source.transbuf
    while nread < total
        n = min(size(readbuf, 2), total - nread)
        nr = sf_readf(source.filePtr, readbuf, n)
        # the data comes in interleaved, so we need to transpose
        transpose!(transbuf, readbuf)
        for ch in 1:nchannels(buf)
            for i in 1:nr
                buf[nread+(i), ch] = transbuf[i, ch]
            end
        end
        source.pos += nr
        nread += nr
        nr == n || break
    end

    nread
end

function Base.readall(str::SndFileSource)
    read(str, nframes(str) - str.pos + 1)
end

function load(path::File)
    str = loadstream(path)
    buf = try
        readall(str)
    finally
        close(str)
    end

    buf
end

savestream(path::AbstractString, args...; kwargs...) =
    savestream(query(path), args...; kwargs...)

function savestream(f::Function, args...)
    stream = savestream(args...)
    try
        f(stream)
    finally
        close(stream)
    end
end

# if the samplerate is given in Hz, strip it off
function savestream{SRT}(path::File, nchannels, samplerate::quantity(SRT, Hz), elemtype)
    savestream(path, nchannels, samplerate/Hz, elemtype)
end

function savestream{T}(path::File{T}, nchannels, samplerate, elemtype)
    sfinfo = SF_INFO(0, 0, 0, 0, 0, 0)

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

    filePtr = ccall((:sf_open, libsndfile), Ptr{Void},
                    (Ptr{UInt8}, Int32, Ptr{SF_INFO}),
                    filename(path), SFM_WRITE, &sfinfo)

    if filePtr == C_NULL
        errmsg = ccall((:sf_strerror, libsndfile), Ptr{UInt8}, (Ptr{Void},), filePtr)
        error("LibSndFile.jl error while saving $path: ", unsafe_string(errmsg))
    end

    SndFileSink(filename(path), filePtr, sfinfo)
end

# returns the number of samples written
function unsafe_write(str::SndFileSink, buf::SampleBuf)
    # the data needs to be interleaved, so we transpose
    arr = buf.data'
    str.nframes += nframes(buf)
    sf_writef(str.filePtr, arr, nframes(buf))
end

function Base.close(str::SndFileSink)
    err = ccall((:sf_close, libsndfile), Int32, (Ptr{Void},), str.filePtr)
    if err != 0
        error("LibSndFile.jl error while saving $path: Failed to close file")
    end
end

function save{T}(path::File{T}, buf::SampleBuf)
    sfinfo = SF_INFO(0, 0, 0, 0, 0, 0)
    stream = savestream(path, nchannels(buf), samplerate(buf), eltype(buf))

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

sf_readf{T <: Union{Int16, PCM16Sample}}(filePtr, dest::Array{T}, nframes) =
    ccall((:sf_readf_short, libsndfile), Int64,
        (Ptr{Void}, Ptr{T}, Int64),
        filePtr, dest, nframes)

sf_readf{T <: Union{Int32, PCM32Sample}}(filePtr, dest::Array{T}, nframes) =
    ccall((:sf_readf_int, libsndfile), Int64,
        (Ptr{Void}, Ptr{T}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{Float32}, nframes) =
    ccall((:sf_readf_float, libsndfile), Int64,
        (Ptr{Void}, Ptr{Float32}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{Float64}, nframes) =
    ccall((:sf_readf_double, libsndfile), Int64,
        (Ptr{Void}, Ptr{Float64}, Int64),
        filePtr, dest, nframes)

"""
Wrappers for the family of sf_writef_* functions, which write the given number
of frames into the given array. Returns the number of frames written.
"""
function sf_writef end

sf_writef{T <: Union{Int16, PCM16Sample}}(filePtr, src::Array{T}, nframes) =
    ccall((:sf_writef_short, libsndfile), Int64,
                (Ptr{Void}, Ptr{T}, Int64),
                filePtr, src, nframes)

sf_writef{T <: Union{Int32, PCM32Sample}}(filePtr, src::Array{T}, nframes) =
    ccall((:sf_writef_int, libsndfile), Int64,
                (Ptr{Void}, Ptr{T}, Int64),
                filePtr, src, nframes)

sf_writef(filePtr, src::Array{Float32}, nframes) =
    ccall((:sf_writef_float, libsndfile), Int64,
                (Ptr{Void}, Ptr{Float32}, Int64),
                filePtr, src, nframes)

sf_writef(filePtr, src::Array{Float64}, nframes) =
    ccall((:sf_writef_double, libsndfile), Int64,
                (Ptr{Void}, Ptr{Float64}, Int64),
                filePtr, src, nframes)

#
# function Base.seek(file::AudioFile, offset::Integer, whence::Integer)
#     new_offset = ccall((:sf_seek, libsndfile), Int64,
#         (Ptr{Void}, Int64, Int32), file.filePtr, offset, whence)
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
