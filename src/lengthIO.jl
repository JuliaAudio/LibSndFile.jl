# wrapper around an arbitrary IO stream that also includes its length, which
# libsndfile requires. Needs to be mutable so it's stored as a reference and
# we can pass a pointer into the C code
mutable struct LengthIO{T<:IO} <: IO
    io::T
    length::Int
end

Base.length(io::LengthIO) = io.length
for f in (:read, :read!, :write, :readbytes!,
          :unsafe_read, :unsafe_write,
          :seek, :seekstart, :seekend, :position, :skip,
          :close)
    @eval @inline Base.$f(io::LengthIO, args...) = $f(io.io, args...)
end
# needed for method ambiguity resolution
Base.readbytes!(io::LengthIO, arr::AbstractArray{UInt8,N} where N) = readbytes!(io.io, arr)
Base.unsafe_write(io::LengthIO, ptr::Ptr, count::Integer) = unsafe_write(io.io, ptr, count)

"""
    inferlen(io)

Try to infer the length of `io` in bytes
"""
inferlen(io::IOBuffer) = io.size
inferlen(io::IOStream) = filesize(io)
function inferlen(io::Stream)
    fname = filename(io)
    if fname !== nothing
        filesize(fname)
    else
        inferlen(stream(io))
    end
end
inferlen(io) = throw(ArgumentError("file length could not be inferred and must be passed explicitly"))
