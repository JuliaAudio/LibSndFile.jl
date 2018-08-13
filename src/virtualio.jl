# libsndfile has the ability to define a virtual IO interface where you provide
# callbacks for read, write, etc, and whenever the library wants to perform
# these operations it calls your functions. See http://www.mega-nerd.com/libsndfile/api.html#open_virtual
# for details.

# Here we define a set of functions that work with general IO types, and we
# have a parametric VIRTUAL_IO function that specializes these functions for a
# particular IO type, and creates a struct of the resulting c-callable function
# pointers.

# we don't in general know the stream length
function virtual_get_filelen(userdata)::sf_count_t
    io = unsafe_pointer_to_objref(userdata)
    # io is a LengthIO, which is a wrapper for a generic IO that also supports
    # the `length` function
    length(io)
end

function virtual_seek(offset, whence, userdata)::sf_count_t
    io = unsafe_pointer_to_objref(userdata)
    if whence == SF_SEEK_SET
        seek(io, offset)
        offset
    elseif whence == SF_SEEK_CUR
        cur = position(io)
        skip(io, offset)
        cur+offset
    elseif whence == SF_SEEK_END
        seekend(io)
        skip(io, offset)
        position(io)
    else
        throw(ArgumentError("Got `whence` value of $whence. Expected 0, 1, or 2"))
    end
end

function virtual_read(dest, count, userdata)::sf_count_t
    io = unsafe_pointer_to_objref(userdata)
    read = readbytes!(io, unsafe_wrap(Array, Ptr{UInt8}(dest), count))

    read
end

function virtual_write(src, count, userdata)::sf_count_t
    io = unsafe_pointer_to_objref(userdata)
    unsafe_write(io, src, count)
    count
end
function virtual_tell(userdata)::sf_count_t
    io = unsafe_pointer_to_objref(userdata)
    position(io)
end

# this contains a collection of function pointers that libsndfile uses to
# read and write data in a buffer
struct SF_VIRTUAL_IO
    get_filelen::Ptr{Cvoid}
    seek::Ptr{Cvoid}
    read::Ptr{Cvoid}
    write::Ptr{Cvoid}
    tell::Ptr{Cvoid}
end

# make a struct of function pointers where the userdata argument is a pointer of
# the specified type
function SF_VIRTUAL_IO(::Type{T}) where T<:IO
    SF_VIRTUAL_IO(
        @cfunction(virtual_get_filelen, sf_count_t, (Ptr{T}, )),
        @cfunction(virtual_seek,        sf_count_t, (sf_count_t, Int32, Ptr{T})),
        @cfunction(virtual_read,        sf_count_t, (Ptr{Cvoid}, sf_count_t, Ptr{T})),
        @cfunction(virtual_write,       sf_count_t, (Ptr{Cvoid}, sf_count_t, Ptr{T})),
        @cfunction(virtual_tell,        sf_count_t, (Ptr{T}, ))
    )
end
