function version()
  SFC_GET_LIB_VERSION	= 0x1000
  buf = zeros(Cchar,256)
  v = Cstring(pointer(buf))
  ccall((:sf_command, libsndfile), Int64,
        (Ptr{Cvoid}, UInt, Cstring, UInt),
        C_NULL, SFC_GET_LIB_VERSION, v, sizeof(buf))
  unsafe_string(v)
end

function sf_strerror(filePtr)
  errmsg = ccall((:sf_strerror, libsndfile), Ptr{UInt8}, (Ptr{Cvoid},), filePtr)
  unsafe_string(errmsg)
end
