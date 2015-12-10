module LibSndFile

using SampleTypes
using FileIO

include("formats.jl")
include(Pkg.dir("LibSndFile", "deps", "deps.jl"))

# const SF_SEEK_SET = 0
# const SF_SEEK_CUR = 1
# const SF_SEEK_END = 2

const SFM_READ = Int32(0x10)
const SFM_WRITE = Int32(0x20)

# const EXT_TO_FORMAT = [
#     ".wav" => SF_FORMAT_WAV,
#     ".flac" => SF_FORMAT_FLAC
# ]

# register FileIO formats
# TODO: coordinate this registration with .avi files, which also start with "RIFF"
# add_format(format"WAV", "RIFF", [".wav"])

"""Take a LibSndFile formata code and return a suitable sample type"""
function fmt_to_type(fmt)
    mapping = Dict{UInt32, Type}(
        SF_FORMAT_PCM_S8 => Int16,
        SF_FORMAT_PCM_U8 => Int16,
        SF_FORMAT_PCM_16 => Int16,
        SF_FORMAT_PCM_24 => Int32,
        SF_FORMAT_PCM_32 => Int32,
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

    # function SF_INFO(frames::Integer, samplerate::Integer, channels::Integer,
    #                  format::Integer, sections::Integer, seekable::Integer)
    #     new(int64(frames), int32(samplerate), int32(channels), int32(format),
    #         int32(sections), int32(seekable))
    # end
end

type SndFileSink{N, SR, T} <: SampleSink{N, SR, T}
    filePtr::Ptr{Void}
    sfinfo::SF_INFO
end

type SndFileSource{N, SR, T} <: SampleSource{N, SR, T}
    filePtr::Ptr{Void}
    sfinfo::SF_INFO
end

# function FileIO.load(path::File{format"WAV"})
function load(path)
    sfinfo = SF_INFO(0, 0, 0, 0, 0, 0)
    file_mode = SFM_READ

    # if mode == "w"
    #     file_mode = SFM_WRITE
    #     sfinfo.samplerate = sampleRate
    #     sfinfo.channels = channels
    #     if format == 0
    #         _, ext = splitext(path)
    #         sfinfo.format = EXT_TO_FORMAT[ext] | SF_FORMAT_PCM_16
    #     else
    #         sfinfo.format = format
    #     end
    # end
    #
    filePtr = ccall((:sf_open, libsndfile), Ptr{Void},
                    (Ptr{UInt8}, Int32, Ptr{SF_INFO}),
                    path, file_mode, &sfinfo)

    if filePtr == C_NULL
        errmsg = ccall((:sf_strerror, libsndfile), Ptr{UInt8}, (Ptr{Void},), filePtr)
        error(bytestring(errmsg))
    end

    arr, nread = try
        T = fmt_to_type(sfinfo.format)
        nframes = sfinfo.frames
        nchannels = sfinfo.channels

        # the data comes in interleaved, so we need to transpose
        arr = Array(T, nchannels, nframes)
        nread = sf_readf(filePtr, arr, nframes)

        (arr, nread)
    finally
        # make sure we close the file even if something goes wrong
        err = ccall((:sf_close, libsndfile), Int32, (Ptr{Void},), filePtr)
        if err != 0
            error("Failed to close file $path")
        end
    end

    TimeSampleBuf(arr[:, 1:nread]', sfinfo.samplerate)
end

# function Base.close(file::AudioFile)
#     err = ccall((:sf_close, libsndfile), Int32, (Ptr{Void},), file.filePtr)
#     if err != 0
#         error("Failed to close file")
#     end
# end
#
# function load(f::Function, args...)
#     file = AudioIO.open(args...)
#     try
#         f(file)
#     finally
#         close(file)
#     end
# end

"""
Wrappers for the family of sf_readf_* functions, which read the given number
of frames into the given array. Returns the number of frames read.
"""
function sf_readf end

sf_readf(filePtr, dest::Array{Int16}, nframes) =
    ccall((:sf_readf_short, libsndfile), Int64,
        (Ptr{Void}, Ptr{Int16}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{Int32}, nframes) =
    ccall((:sf_readf_int, libsndfile), Int64,
        (Ptr{Void}, Ptr{Int32}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{Float32}, nframes) =
    ccall((:sf_readf_float, libsndfile), Int64,
        (Ptr{Void}, Ptr{Float32}, Int64),
        filePtr, dest, nframes)

sf_readf(filePtr, dest::Array{Float64}, nframes) =
    ccall((:sf_readf_double, libsndfile), Int64,
        (Ptr{Void}, Ptr{Float64}, Int64),
        filePtr, dest, nframes)

# function Base.write{T}(file::AudioFile, frames::Array{T})
#     @assert file.sfinfo.channels <= 2
#     nframes = int(length(frames) / file.sfinfo.channels)
#
#     if T == Int16
#         return ccall((:sf_writef_short, libsndfile), Int64,
#                         (Ptr{Void}, Ptr{Int16}, Int64),
#                         file.filePtr, frames, nframes)
#     elseif T == Int32
#         return ccall((:sf_writef_int, libsndfile), Int64,
#                         (Ptr{Void}, Ptr{Int32}, Int64),
#                         file.filePtr, frames, nframes)
#     elseif T == Float32
#         return ccall((:sf_writef_float, libsndfile), Int64,
#                         (Ptr{Void}, Ptr{Float32}, Int64),
#                         file.filePtr, frames, nframes)
#     elseif T == Float64
#         return ccall((:sf_writef_double, libsndfile), Int64,
#                         (Ptr{Void}, Ptr{Float64}, Int64),
#                         file.filePtr, frames, nframes)
#     end
# end
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
