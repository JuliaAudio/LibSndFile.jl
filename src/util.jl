nframes(buf::Vector) = length(buf)
nframes(buf::Matrix) = size(buf, 2)

nchannels(buf::Vector) = 1
nchannels(buf::Matrix) = size(buf, 1)
