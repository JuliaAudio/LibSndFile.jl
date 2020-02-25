"""
    read!(src::SndFileSource, buf::AbstractArray)

Read frames of audio from `src` into `buf`. Returns the number of frames read. A
frame is a sample in time across all channels.
"""
function Base.read!(source::SndFileSource, buf::Array)
    # when given a regular array we can just read directly into it
    if nchannels(source) != nchannels(buf)
        throw(ArgumentError(
            "Tried to read $(nchannels(source))-channel source into $(nchannels(buf))-channel array"))
    end
    nr = sf_readf(source.filePtr, readbuf)
    source.pos += nr

    Int(nr)
end

# for other types of AbstractArray we read into our temp buffer and then copy
function Base.read!(source::SndFileSource, buf::AbstractArray)
    total = min(nframes(buf), nframes(source) - source.pos + 1)
    nread = 0
    readbuf = source.readbuf
    ridxs = CartesianIndices(readbuf)
    while nread < total
        nr = read!(source, readbuf)
        copyto!(buf, ridxs .+ CartesianIndex((0,nread)), readbuf, ridxs)
        nread += nr
        nr == nframes(readbuf) || break # abort if we receive fewer frames than we expected
    end

    nread
end

function Base.read(source::SndFileSource, nframes)
    buf = zeros(eltype(source), nchannels(source), nframes)
    nr = read!(source, buf)
    if nr < nframes
        resize!(buf, size(buf, 1), nr)
    end

    buf
end

# returns the number of samples written
function SampledSignals.unsafe_write(sink::SndFileSink, buf::Array, frameoffset, framecount)
    nwritten = 0
    writebuf = sink.writebuf
    while nwritten < framecount
        n = min(size(writebuf, 2), framecount - nwritten)
        # the data needs to be interleaved, so we need to transpose
        transpose!(view(writebuf, :, 1:n),
                   view(buf, (1:n) .+ frameoffset .+ nwritten, :))
        # transpose! needs the ranges to all use Ints, which on 32-bit systems
        # is an Int32, but sf_writef returns Int64 on both platforms, so we
        # convert to a platform-native Int. This also avoids a
        # type-inferrability problem where `nw` would otherwise change type.
        nw::Int = sf_writef(sink.filePtr, writebuf, n)
        sink.nframes += nw
        nwritten += nw
        nw == n || break
    end

    nwritten
end
