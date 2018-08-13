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

mutable struct SndFileSink{T, S<:Union{String, LengthIO}} <: SampleSink
    src::S # the stream or filename used to create this
    filePtr::Ptr{Cvoid}
    sfinfo::SF_INFO
    nframes::Int64
    writebuf::Array{T, 2}
end

function SndFileSink(src, filePtr, sfinfo, bufsize=4096)
    T = fmt_to_type(sfinfo.format)
    writebuf = zeros(T, sfinfo.channels, bufsize)
    SndFileSink(src, filePtr, sfinfo, 0, writebuf)
end

const SndFileStream{T, S} = Union{SndFileSource{T, S}, SndFileSink{T, S}}

SampledSignals.nchannels(str::SndFileStream) = Int(str.sfinfo.channels)
SampledSignals.samplerate(str::SndFileStream) = str.sfinfo.samplerate
Base.eltype(str::SndFileStream{T, S}) where {T, S} = T

SampledSignals.nframes(sink::SndFileSink) = sink.nframes
SampledSignals.nframes(source::SndFileSource) = source.sfinfo.frames

function Base.close(s::SndFileStream)
    if s.filePtr != C_NULL
        sf_close(s.filePtr)
        s.filePtr = C_NULL
    else
        @warn "close called more than once on $s"
    end
end

function Base.show(io::IO, s::SndFileStream)
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
