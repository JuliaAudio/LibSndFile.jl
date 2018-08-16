# Masks

const SF_FORMAT_ENDMASK   = 0x30000000
const SF_FORMAT_TYPEMASK  = 0x0FFF0000
const SF_FORMAT_SUBMASK   = 0x0000FFFF

# Endian-ness options

const SF_ENDIAN_FILE      = 0x00000000 # Default file endian-ness.
const SF_ENDIAN_LITTLE    = 0x10000000 # Force little endian-ness.
const SF_ENDIAN_BIG       = 0x20000000 # Force big endian-ness.
const SF_ENDIAN_CPU       = 0x30000000 # Force CPU endian-ness.

# Major Formats

const SF_FORMAT_WAV       = 0x00010000 # Microsoft WAV format (little endian).
const SF_FORMAT_AIFF      = 0x00020000 # Apple/SGI AIFF format (big endian).
const SF_FORMAT_AU        = 0x00030000 # Sun/NeXT AU format (big endian).
const SF_FORMAT_RAW       = 0x00040000 # RAW PCM data.
const SF_FORMAT_PAF       = 0x00050000 # Ensoniq PARIS file format.
const SF_FORMAT_SVX       = 0x00060000 # Amiga IFF / SVX8 / SV16 format.
const SF_FORMAT_NIST      = 0x00070000 # Sphere NIST format.
const SF_FORMAT_VOC       = 0x00080000 # VOC files.
const SF_FORMAT_IRCAM     = 0x000A0000 # Berkeley/IRCAM/CARL
const SF_FORMAT_W64       = 0x000B0000 # Sonic Foundry's 64 bit RIFF/WAV
const SF_FORMAT_MAT4      = 0x000C0000 # Matlab (tm) V4.2 / GNU Octave 2.0
const SF_FORMAT_MAT5      = 0x000D0000 # Matlab (tm) V5.0 / GNU Octave 2.1
const SF_FORMAT_PVF       = 0x000E0000 # Portable Voice Format
const SF_FORMAT_XI        = 0x000F0000 # Fasttracker 2 Extended Instrument
const SF_FORMAT_HTK       = 0x00100000 # HMM Tool Kit format
const SF_FORMAT_SDS       = 0x00110000 # Midi Sample Dump Standard
const SF_FORMAT_AVR       = 0x00120000 # Audio Visual Research
const SF_FORMAT_WAVEX     = 0x00130000 # MS WAVE with WAVEFORMATEX
const SF_FORMAT_SD2       = 0x00160000 # Sound Designer 2
const SF_FORMAT_FLAC      = 0x00170000 # FLAC lossless file format
const SF_FORMAT_CAF       = 0x00180000 # Core Audio File format
const SF_FORMAT_WVE       = 0x00190000 # Psion WVE format
const SF_FORMAT_OGG       = 0x00200000 # Xiph OGG container
const SF_FORMAT_MPC2K     = 0x00210000 # Akai MPC 2000 sampler
const SF_FORMAT_RF64      = 0x00220000 # RF64 WAV file

# SubFormats

const SF_FORMAT_PCM_S8    = 0x00000001 # Signed 8 bit data
const SF_FORMAT_PCM_16    = 0x00000002 # Signed 16 bit data
const SF_FORMAT_PCM_24    = 0x00000003 # Signed 24 bit data
const SF_FORMAT_PCM_32    = 0x00000004 # Signed 32 bit data
const SF_FORMAT_PCM_U8    = 0x00000005 # Unsigned 8 bit data (WAV and RAW only)
const SF_FORMAT_FLOAT     = 0x00000006 # 32 bit float data
const SF_FORMAT_DOUBLE    = 0x00000007 # 64 bit float data
const SF_FORMAT_ULAW      = 0x00000010 # U-Law encoded.
const SF_FORMAT_ALAW      = 0x00000011 # A-Law encoded.
const SF_FORMAT_IMA_ADPCM = 0x00000012 # IMA ADPCM.
const SF_FORMAT_MS_ADPCM  = 0x00000013 # Microsoft ADPCM.
const SF_FORMAT_GSM610    = 0x00000020 # GSM 6.10 encoding.
const SF_FORMAT_VOX_ADPCM = 0x00000021 # Oki Dialogic ADPCM encoding.
const SF_FORMAT_G721_32   = 0x00000030 # 32kbs G721 ADPCM encoding.
const SF_FORMAT_G723_24   = 0x00000031 # 24kbs G723 ADPCM encoding.
const SF_FORMAT_G723_40   = 0x00000032 # 40kbs G723 ADPCM encoding.
const SF_FORMAT_DWVW_12   = 0x00000040 # 12 bit Delta Width Variable Word encoding.
const SF_FORMAT_DWVW_16   = 0x00000041 # 16 bit Delta Width Variable Word encoding.
const SF_FORMAT_DWVW_24   = 0x00000042 # 24 bit Delta Width Variable Word encoding.
const SF_FORMAT_DWVW_N    = 0x00000043 # N bit Delta Width Variable Word encoding.
const SF_FORMAT_DPCM_8    = 0x00000050 # 8 bit differential PCM (XI only)
const SF_FORMAT_DPCM_16   = 0x00000051 # 16 bit differential PCM (XI only)
const SF_FORMAT_VORBIS    = 0x00000060 # Xiph Vorbis encoding.

# Library flags

# const SF_SEEK_SET = 0
# const SF_SEEK_CUR = 1
# const SF_SEEK_END = 2

const SFM_READ = Int32(0x10)
const SFM_WRITE = Int32(0x20)

const SF_SEEK_SET = Int32(0)
const SF_SEEK_CUR = Int32(1)
const SF_SEEK_END = Int32(2)

formatcode(::Type{format"WAV"}) = SF_FORMAT_WAV
formatcode(::Type{format"FLAC"}) = SF_FORMAT_FLAC
formatcode(::Type{format"OGG"}) = SF_FORMAT_OGG

subformatcode(::Type{PCM16Sample}) = SF_FORMAT_PCM_16
subformatcode(::Type{PCM32Sample}) = SF_FORMAT_PCM_32
subformatcode(::Type{Float32}) = SF_FORMAT_FLOAT
subformatcode(::Type{Float64}) = SF_FORMAT_DOUBLE

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

const sf_count_t = Int64

mutable struct SF_INFO
    frames::sf_count_t
    samplerate::Int32
    channels::Int32
    format::Int32
    sections::Int32
    seekable::Int32
end

SF_INFO() = SF_INFO(0, 0, 0, 0, 0, 0)

function sf_open(fname::String, mode, sfinfo)
    filePtr = ccall((:sf_open, libsndfile), Ptr{Cvoid},
                    (Cstring, Int32, Ref{SF_INFO}),
                    fname, mode, sfinfo)

    if filePtr == C_NULL
        error("LibSndFile.jl error while opening $fname: ", sf_strerror(C_NULL))
    end

    filePtr
end

# internals to get the virtual IO interface working
include("virtualio.jl")

function sf_open(io::T, mode, sfinfo) where T <: IO
    virtio = SF_VIRTUAL_IO(T)
    filePtr = ccall((:sf_open_virtual, libsndfile), Ptr{Cvoid},
                    (Ref{SF_VIRTUAL_IO}, Int32, Ref{SF_INFO}, Ptr{T}),
                    virtio, mode, sfinfo, pointer_from_objref(io))
    if filePtr == C_NULL
        error("LibSndFile.jl error while opening stream: ", sf_strerror(C_NULL))
    end

    filePtr
end

function sf_close(filePtr)
    err = ccall((:sf_close, libsndfile), Int32, (Ptr{Cvoid},), filePtr)
    if err != 0
        error("LibSndFile.jl error: Failed to close file: ", sf_strerror(filePtr))
    end
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

function sf_strerror(filePtr)
    errmsg = ccall((:sf_strerror, libsndfile), Ptr{UInt8}, (Ptr{Cvoid},), filePtr)
    unsafe_string(errmsg)
end
