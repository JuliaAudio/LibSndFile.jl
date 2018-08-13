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
