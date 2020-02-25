#!/usr/bin/env julia

using Test
using FileIO: File, Stream, @format_str
import FileIO
import LibSndFile
using SampledSignals

include("testhelpers.jl")

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
        for fmt in (("_wav", format"WAV"), ("_ogg", format"OGG"), ("_flac", format"FLAC"))
            @eval $(Symbol(f, fmt[1]))(io::$(io[1]), args...) =
                LibSndFile.$f($(io[2])($(fmt[2]), io), args...)
            if f in (:loadstreaming, :savestreaming)
                @eval function $(Symbol(f, fmt[1]))(dofunc::Function, io::$(io[1]), args...)
                    str = LibSndFile.$f($(io[2])($(fmt[2]), io), args...)
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

"""Generates a 100-sample 2-channel signal"""
function gen_reference(srate)
    t = collect(0:99) / srate
    phase = [2pi*440t 2pi*880t]

    0.5sin.(phase)
end

srate = 44100
# reference file generated with Audacity. Careful to turn dithering off
# on export for deterministic output!
reference_wav = joinpath(dirname(@__FILE__), "440left_880right_0.5amp.wav")
reference_wav_float = joinpath(dirname(@__FILE__), "440left_880right_0.5amp_float.wav")
reference_wav_double = joinpath(dirname(@__FILE__), "440left_880right_0.5amp_double.wav")
reference_wav_pcm24 = joinpath(dirname(@__FILE__), "440left_880right_0.5amp_pcm24.wav")
reference_ogg = joinpath(dirname(@__FILE__), "440left_880right_0.5amp.ogg")
reference_flac = joinpath(dirname(@__FILE__), "440left_880right_0.5amp.flac")
reference_buf = gen_reference(srate)

# don't indent the individual testsets so we can more easily run them from
# Juno
@testset "LibSndFile Tests" begin

@testset "Read errors" begin
    @test_throws ErrorException load_wav("doesnotexist.wav")
end

@testset "WAV file reading" begin
    buf = load_wav(reference_wav)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/(srate))
    @test mse(buf, reference_buf) < 1e-10
end

@testset "Reading different sample types" begin
    buf = load_wav(reference_wav)
    @test eltype(buf) == PCM16Sample

    buf_float = load_wav(reference_wav_float)
    @test eltype(buf_float) == Float32
    @test mse(buf_float, reference_buf) < 1e-10

    buf_double = load_wav(reference_wav_double)
    @test eltype(buf_double) == Float64
    @test mse(buf_double, reference_buf) < 1e-10

    buf_pcm24 = load_wav(reference_wav_pcm24)
    @test eltype(buf_pcm24) == PCM32Sample
    @test mse(buf_pcm24, reference_buf) < 1e-10
end

@testset "FLAC file reading" begin
    buf = load_flac(reference_flac)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/srate)
    @test mse(buf, reference_buf) < 1e-10
end

@testset "OGG file reading" begin
    buf = load_ogg(reference_ogg)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/srate)
    # lossy compression, so relax the accuracy a bit
    @test mse(buf, reference_buf) < 1e-5
end

@testset "Streaming reading" begin
    str = loadstreaming_wav(reference_wav)
    @test nframes(str) == 100
    @test position(str) == 1
    @test mse(read(str, 50), reference_buf[1:50, :]) < 1e-10
    @test mse(read(str, 50), reference_buf[51:100, :]) < 1e-10
    close(str)
    # now with do syntax
    loadstreaming_wav(reference_wav) do str
        @test mse(read(str, 50), reference_buf[1:50, :]) < 1e-10
        @test mse(read(str, 50), reference_buf[51:100, :]) < 1e-10
    end
    # now try reading all at once
    loadstreaming_wav(reference_wav) do str
        @test mse(read(str), reference_buf) < 1e-10
    end

    # seeking
    loadstreaming_wav(reference_wav) do str
        seek(str, 22)
        @test mse(read(str), reference_buf[22:end, :]) < 1e-10
    end

    # skipping
    loadstreaming_wav(reference_wav) do str
        seek(str, 22)
        skip(str, 10)
        @test mse(read(str), reference_buf[32:end, :]) < 1e-10
    end

end

@testset "Reading from IO Stream" begin
    open(reference_wav) do io
        loadstreaming_wav(io) do str
            @test nframes(str) == 100
            @test mse(read(str), reference_buf) < 1e-10
        end
    end
    open(reference_wav) do io
        buf = load_wav(io)
        @test samplerate(buf) == srate
        @test nchannels(buf) == 2
        @test nframes(buf) == 100
        @test isapprox(domain(buf), collect(0:99)/(srate))
        @test mse(buf, reference_buf) < 1e-10
    end
end

@testset "Writing to IO Streams" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 100, 2) .- 0.5, srate)
    open(fname, "w") do io
        savestreaming_wav(io, 2, srate, Float32) do str
            write(str, testbuf[1:50, :])
            write(str, testbuf[51:100, :])
        end
    end
    @test load_wav(fname) == testbuf
    fname = string(tempname(), ".wav")
    open(fname, "w") do io
        save_wav(io, testbuf)
    end
    @test load_wav(fname) == testbuf
end

@testset "Supports IOBuffer" begin
    io = IOBuffer()
    testbuf = SampleBuf(rand(100, 2) .- 0.5, srate)
    save_wav(io, testbuf)
    seek(io, 0)
    @test load_wav(io) == testbuf
end

@testset "WAV file writing (float64)" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(100, 2) .- 0.5, srate)
    save_wav(fname, testbuf)
    buf = load_wav(fname)
    @test eltype(buf) == eltype(testbuf)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/srate)
    @test mse(buf, testbuf) < 1e-10
end

@testset "WAV file writing (float32)" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 100, 2) .- 0.5f0, srate)
    save_wav(fname, testbuf)
    buf = load_wav(fname)
    @test eltype(buf) == eltype(testbuf)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/srate)
    @test mse(buf, testbuf) < 1e-10
end

@testset "OGG file writing" begin
    fname = string(tempname(), ".ogg")
    testbuf = SampleBuf(rand(Float32, 100, 2) .- 0.5, srate)
    save_ogg(fname, testbuf)
    buf = load_ogg(fname)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/srate)
    # noise doesn't compress very well...
    @test mse(buf, testbuf) < 0.05
end

@testset "FLAC file writing" begin
    fname = string(tempname(), ".flac")
    arr = map(PCM16Sample, rand(100, 2) .- 0.5)
    testbuf = SampleBuf(arr, srate)
    save_flac(fname, testbuf)
    buf = load_flac(fname)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/srate)
    @test mse(buf, testbuf) < 1e-10
end

@testset "Writing $T data" for T in [PCM16Sample, PCM32Sample, Float32, Float64]
    fname = string(tempname(), ".wav")
    arr = map(T, rand(100, 2) .- 0.5)
    testbuf = SampleBuf(arr, srate)
    save_wav(fname, testbuf)
    buf = load_wav(fname)
    @test eltype(buf) == T
    @test mse(buf, testbuf) < 1e-10
end

@testset "Write errors" begin
    testbuf = SampleBuf(rand(Float32, 100, 2) .- 0.5, srate)
    flacname = string(tempname(), ".flac")
    @test_throws ErrorException save_flac(abspath("doesnotexist.wav"), testbuf)
    @test_throws ErrorException save_flac(flacname, testbuf)
end

@testset "Streaming writing" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 100, 2) .- 0.5, srate)
    # set up a 2-channel Float32 stream
    stream = savestreaming_wav(fname, 2, srate, Float32)
    write(stream, testbuf[1:50, :])
    write(stream, testbuf[51:100, :])
    close(stream)
    buf = load_wav(fname)
    @test mse(buf, testbuf) < 1e-10

    # now with do syntax
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 100, 2) .- 0.5, srate)
    # set up a 2-channel Float32 stream
    savestreaming_wav(fname, 2, srate, Float32) do stream
        write(stream, testbuf[1:50, :])
        write(stream, testbuf[51:100, :])
    end
    buf = load_wav(fname)
    @test mse(buf, testbuf) < 1e-10

end

@testset "FileIO Integration" begin
    arr = map(PCM16Sample, rand(100, 2) .- 0.5)
    testbuf = SampleBuf(arr, srate)
    for ext in (".wav", ".ogg", ".flac")
        fname = string(tempname(), ext)
        FileIO.save(fname, testbuf)
        buf = FileIO.load(fname)
        @test buf isa SampleBuf
    end
end

@testset "Sink Display" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 10000, 2) .- 0.5f0, srate)
    # set up a 2-channel Float32 stream
    stream = savestreaming_wav(fname, 2, srate, Float32)
    io = IOBuffer()
    show(io, stream)
    @test String(take!(io)) == """
    LibSndFile.SndFileSink{Float32,String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 0 of 0 frames
                0.00 of 0.00 seconds"""
    write(stream, testbuf)
    show(io, stream)
    @test String(take!(io)) == """
    LibSndFile.SndFileSink{Float32,String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 10000 of 10000 frames
                0.23 of 0.23 seconds"""
end

@testset "Source Display" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 10000, 2) .- 0.5f0, srate)
    save_wav(fname, testbuf)
    # set up a 2-channel Float32 stream
    stream = loadstreaming_wav(fname)
    io = IOBuffer()
    show(io, stream)
    @test String(take!(io)) == """
    LibSndFile.SndFileSource{Float32,String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 0 of 10000 frames
                0.00 of 0.23 seconds"""
    read(stream, 5000)
    show(io, stream)
    @test String(take!(io)) == """
    LibSndFile.SndFileSource{Float32,String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 5000 of 10000 frames
                0.11 of 0.23 seconds"""
end


# TODO: check out what happens when samplerate, channels, etc. are wrong
# when reading/writing

#
#     # test seeking
#
#     # test rendering as an AudioNode
#     AudioIO.open(fname) do f
#         # pretend we have a stream at the same rate as the file
#         bufsize = 1024
#         input = zeros(AudioSample, bufsize)
#         test_info = DeviceInfo(srate, bufsize)
#         node = FilePlayer(f)
#         # convert to floating point because that's what AudioIO uses natively
#         expected = convert(AudioBuf, reference ./ (2^15))
#         buf = render(node, input, test_info)
#         @fact expected[1:bufsize] => buf[1:bufsize]
#         buf = render(node, input, test_info)
#         @fact expected[bufsize+1:2*bufsize] => buf[1:bufsize]
#     end
# end
#
# @testset "Stereo file reading" begin
#     fname = Pkg.dir("AudioIO", "test", "440left_880right.wav")
#     srate = 44100
#     t = [0 : 2 * srate - 1] / srate
#     expected = int16((2^15-1) * hcat(sin(2pi*t*440), sin(2pi*t*880)))
#
#     AudioIO.open(fname) do f
#         buf = read(f)
#         @fact buf => mse(expected, 5)
#     end
# end
#
# # note - currently AudioIO just mixes down to Mono. soon we'll support this
# # new-fangled stereo sound stuff
# @testset "Stereo file rendering" begin
#     fname = Pkg.dir("AudioIO", "test", "440left_880right.wav")
#     srate = 44100
#     bufsize = 1024
#     input = zeros(AudioSample, bufsize)
#     test_info = DeviceInfo(srate, bufsize)
#     t = [0 : 2 * srate - 1] / srate
#     expected = convert(AudioBuf, 0.5 * (sin(2pi*t*440) + sin(2pi*t*880)))
#
#     AudioIO.open(fname) do f
#         node = FilePlayer(f)
#         buf = render(node, input, test_info)
#         @fact buf[1:bufsize] => mse(expected[1:bufsize])
#         buf = render(node, input, test_info)
#         @fact buf[1:bufsize] => mse(expected[bufsize+1:2*bufsize])
#     end
# end
end # @testset LibSndFile
