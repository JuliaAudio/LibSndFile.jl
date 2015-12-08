#!/usr/bin/env julia

if VERSION >= v"0.5.0-"
    using Base.Test
else
    using BaseTestNext
end

using LibSndFile
using SampleTypes

include("testhelpers.jl")

"""Generates a 2-second stereo TimeSampleBuf"""
function gen_reference(srate)
    t = collect(0:99) / srate
    phase = [2pi*440t 2pi*880t]

    TimeSampleBuf(round(Int16, (2 ^ 15 - 1) * 0.5sin(phase)), srate)
end

try
    @testset "LibSndFile Tests" begin
        srate = 44100
        # reference file generated with Audacity. Careful to turn dithering off
        # on export for deterministic output!
        reference_file = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.wav")
        reference_buf = gen_reference(srate)

        @testset "WAV file reading" begin
            buf = LibSndFile.load(reference_file)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf[1:20, :], reference_buf[1:20, :]) < 1
        end
        #
        # @testset "WAV file writing" begin
        #     writename = string(tempname(), ".wav")
        #
        #
        #     AudioIO.open(fname, "w") do f
        #         write(f, reference)
        #     end
        #
        #     # test basic reading
        #     AudioIO.open(fname) do f
        #         @fact f.sfinfo.channels => 1
        #         @fact f.sfinfo.frames => 2 * srate
        #         actual = read(f)
        #         @fact length(reference) => length(actual)
        #         @fact reference => actual[:, 1]
        #         @fact samplerate(f) => srate
        #     end
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
    end
catch err
    exit(-1)
end
