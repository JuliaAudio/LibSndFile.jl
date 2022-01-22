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
