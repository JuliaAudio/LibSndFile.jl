srate = 44100
# convenience function to calculate the mean-squared error
mse(x,y) = norm(x-y)^2/length(x)

# Generates a 100-sample 2-channel signal
function gen_reference(srate)
    t = collect(0:99) / srate
    phase = [2pi*440t 2pi*880t]
    0.5sin.(phase)
end

# reference file generated with Audacity. Careful to turn dithering off
# on export for deterministic output!
reference_wav = "data/440left_880right_0.5amp.wav"
reference_wav_float = "data/440left_880right_0.5amp_float.wav"
reference_wav_double = "data/440left_880right_0.5amp_double.wav"
reference_wav_pcm24 = "data/440left_880right_0.5amp_pcm24.wav"
reference_ogg = "data/440left_880right_0.5amp.ogg"
reference_flac = "data/440left_880right_0.5amp.flac"
reference_buf = gen_reference(srate)

# define some loaders and savers that bypass FileIO's detection machinery, of
# the form:
# load_wav(io::String, args...) = LibSndFile.load(File(format"WAV", io), args...)
# load_wav(io::IO, args...) = LibSndFile.load(Stream(format"WAV", io), args...)
# also create do-compatible methods of the form:
# function loadstreaming_wav(dofunc::Function, io::IO, args...)
#     str = LibSndFile.load(dofunc, Stream(format"WAV", io), args...)
#     try
#         dofunc(str)
#     finally
#         close(str)
#     end
# end

for f in (:load, :save, :loadstreaming, :savestreaming)
    for io in ((String, File), (IO, Stream))
        for fmt in formats
            @eval $(Symbol(f, fmt[1]))(io::$(io[1]), args...) =
            LibSndFile.$f($(io[2]){$(fmt[2])}( io), args...)
            if f in (:loadstreaming, :savestreaming)
                @eval function $(Symbol(f, fmt[1]))(dofunc::Function, io::$(io[1]), args...)
                  str = LibSndFile.$f($(io[2]){$(fmt[2])}( io), args...)
                    try
                        dofunc(str)
                    finally
                        close(str)
                    end
                end
            end
        end
    end
end
