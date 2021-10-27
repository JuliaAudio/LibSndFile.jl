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
  ## this fixes #34 however is unstable and breaks test randomly
  ## it's difficult to debug it without a Windows machine 
  #ptr = pointer(transcode(Cwchar_t,fname))
  #filePtr = ccall((:sf_wchar_open, libsndfile), Ptr{Cvoid},
  #                (Cwstring, Int32, Ref{SF_INFO}),
  #                Cwstring(ptr), mode, sfinfo)
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
of frames in the source array to the file. Returns the number of frames written.
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

sf_seek(filePtr, frames::sf_count_t, whence::Integer) =
ccall((:sf_seek, libsndfile), Int64,
      (Ptr{Cvoid}, Int64, Int32),
      filePtr, frames, whence)

function version()
  SFC_GET_LIB_VERSION	= 0x1000
  buf = zeros(Cchar,256) 
  v = Cstring(pointer(buf))
  ccall((:sf_command, libsndfile), Int64,
        (Ptr{Cvoid}, UInt, Cstring, UInt),
        C_NULL, SFC_GET_LIB_VERSION, v, sizeof(buf))
  unsafe_string(v)
end
