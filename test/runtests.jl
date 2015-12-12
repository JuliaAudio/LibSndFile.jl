#!/usr/bin/env julia

if VERSION >= v"0.5.0-"
    using Base.Test
else
    using BaseTestNext
end

using LibSndFile
using SampleTypes
using FileIO

include("testhelpers.jl")

"""Generates a 100-sample 2-channel signal"""
function gen_reference(srate)
    t = collect(0:99) / srate
    phase = [2pi*440t 2pi*880t]

    0.5sin(phase)
end

try
    @testset "LibSndFile Tests" begin
        srate = 44100
        # reference file generated with Audacity. Careful to turn dithering off
        # on export for deterministic output!
        reference_wav = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.wav")
        reference_ogg = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.ogg")
        reference_flac = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.flac")
        reference_buf = gen_reference(srate)

        @testset "Read errors" begin
            STDERR_orig = STDERR
            (rd, rw) = redirect_stderr()
            @test_throws ErrorException load("doesnotexist.wav")
            close(rw) # makes sure all writes are flushed
            # check output here?
            close(rd)
            redirect_stderr(STDERR_orig)
        end
        @testset "WAV file reading" begin
            open(reference_wav) do stream
                @test LibSndFile.detectwav(stream)
            end
            open(reference_flac) do stream
                @test !LibSndFile.detectwav(stream)
            end
            buf = load(reference_wav)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf, reference_buf) < 1e-10
        end

        @testset "FLAC file reading" begin
            buf = load(reference_flac)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf, reference_buf) < 1e-10
        end

        @testset "OGG file reading" begin
            buf = load(reference_ogg)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf, reference_buf) < 1e-5
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
