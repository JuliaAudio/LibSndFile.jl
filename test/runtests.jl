#!/usr/bin/env julia

if VERSION >= v"0.5.0-"
    using Base.Test
else
    using BaseTestNext
end

println("loading LibSndFile")
using LibSndFile
println("loading SampleTypes")
using SampleTypes
println("loading FileIO")
using FileIO
println("Modules loaded")

include("testhelpers.jl")

"""Generates a 100-sample stereo TimeSampleBuf"""
function gen_reference(srate)
    t = collect(0:99) / srate
    phase = [2pi*440t 2pi*880t]

    TimeSampleBuf(round(Int16, (2 ^ 15 - 1) * 0.5sin(phase)), srate)
end

println("Beginning tests")

try
    @testset "LibSndFile Tests" begin
        srate = 44100
        # reference file generated with Audacity. Careful to turn dithering off
        # on export for deterministic output!
        reference_file = File{format"WAV"}(Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.wav"))
        reference_buf = gen_reference(srate)

        @testset "WAV file reading" begin
            println("loading file")
            buf = load(reference_file)
            println("file loaded")
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf[1:20, :], reference_buf[1:20, :]) < 1
        end

        # @testset "WAV file writing" begin
        #     fname = string(tempname(), ".wav")
        #     LibSndFile.save(fname, reference_buf)
        #     buf = LibSndFile.load(fname)
        #     @test samplerate(buf) == srate
        #     @test nchannels(buf) == 2
        #     @test nframes(buf) == 100
        #     @test domain(buf) == collect(0:99)/srate * s
        #     @test mse(buf[1:20, :], reference_buf[1:20, :]) < 1
        # end

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
