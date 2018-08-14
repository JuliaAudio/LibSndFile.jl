function loadstreaming(src::File)
    sfinfo = SF_INFO()
    fname = filename(src)
    # sf_open fills in sfinfo
    filePtr = sf_open(fname, SFM_READ, sfinfo)

    SndFileSource(fname, filePtr, sfinfo)
end

function loadstreaming(src::Stream, filelen=inferlen(src))
    sfinfo = SF_INFO()
    io = LengthIO(stream(src), filelen)
    # sf_open fills in sfinfo
    filePtr = sf_open(io, SFM_READ, sfinfo)

    SndFileSource(io, filePtr, sfinfo)
end

for T in (:File, :Stream), fmt in supported_formats
    @eval @inline load(src::$T{$fmt}, args...) = load_helper(src, args...)
end

# convert a `load` call into a `loadstreaming` call that properly
# cleans up the stream
function load_helper(src::Union{File, Stream}, args...)
    str = loadstreaming(src, args...)
    buf = try
        read(str)
    finally
        close(str)
    end

    buf
end

function savestreaming(src::Union{File{T}, Stream{T}}, nchannels, samplerate, elemtype) where T
    sfinfo = SF_INFO()

    sfinfo.samplerate = samplerate
    sfinfo.channels = nchannels
    sfinfo.format = formatcode(T)
    io = if src isa Stream
        LengthIO(stream(src), 0)
    else
        filename(src)
    end
    # TODO: should we auto-convert 32-bit integer samples to 24-bit?
    if T == format"FLAC" && elemtype != PCM16Sample
        error("LibSndFile.jl: FLAC only supports 16-bit integer samples")
    end
    # will probably need to figure out how this would interact with
    # ogg opus files
    if T == format"OGG"
        sfinfo.format |= SF_FORMAT_VORBIS
    else
        sfinfo.format |= subformatcode(elemtype)
    end

    filePtr = sf_open(io, SFM_WRITE, sfinfo)

    SndFileSink(io, filePtr, sfinfo)
end

for T in (:File, :Stream), fmt in supported_formats
    @eval @inline save(src::$T{$fmt}, args...) = save_helper(src, args...)
end

function save_helper(src, buf::SampleBuf)
    sfinfo = SF_INFO()
    stream = savestreaming(src, nchannels(buf), samplerate(buf), eltype(buf))

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
