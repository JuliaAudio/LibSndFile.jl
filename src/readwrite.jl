function SampledSignals.unsafe_read!(source::SndFileSource, buf::Array, frameoffset, framecount)
    total = min(framecount, nframes(source) - source.pos + 1)
    nread = 0
    readbuf = source.readbuf
    while nread < total
        n = min(size(readbuf, 2), total - nread)
        # transpose! needs the ranges to all use Ints, which on 32-bit systems
        # is an Int32, but sf_writef returns Int64 on both platforms, so we
        # convert to a platform-native Int. This also avoids a
        # type-inferrability problem where `nw` would otherwise change type.
        nr::Int = sf_readf(source.filePtr, readbuf, n)
        # the data comes in interleaved, so we need to transpose
        transpose!(view(buf, (1:nr) .+ frameoffset .+ nread, :),
                   view(readbuf, :, 1:nr))
        source.pos += nr
        nread += nr
        nr == n || break
    end

    nread
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
