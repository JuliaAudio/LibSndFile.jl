#!/usr/bin/env julia

if VERSION >= v"0.5.0-"
    using Base.Test
else
    using BaseTestNext
end

using LibSndFile
using SampleTypes
using FileIO
using FixedPointNumbers

include("testhelpers.jl")

"""Generates a 100-sample 2-channel signal"""
function gen_reference(srate)
    t = collect(0:99) / srate
    phase = [2pi*440t 2pi*880t]

    0.5sin(phase)
end

function Base.redirect_stderr(f::Function)
    STDERR_orig = STDERR
    (rd, rw) = redirect_stderr()
    try
        f(rd, rw)
    finally
        close(rw) # makes sure all writes are flushed
        close(rd)
        redirect_stderr(STDERR_orig)
    end
end

try
    @testset "LibSndFile Tests" begin
        srate = 44100
        # reference file generated with Audacity. Careful to turn dithering off
        # on export for deterministic output!
        reference_wav = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.wav")
        reference_wav_float = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp_float.wav")
        reference_wav_double = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp_double.wav")
        reference_wav_pcm24 = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp_pcm24.wav")
        reference_ogg = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.ogg")
        reference_flac = Pkg.dir("LibSndFile", "test", "440left_880right_0.5amp.flac")
        reference_buf = gen_reference(srate)

        @testset "Read errors" begin
            redirect_stderr() do rd, wr
                @test_throws ErrorException load("doesnotexist.wav")
            end
        end

        @testset "WAV file detection" begin
            open(reference_wav) do stream
                @test LibSndFile.detectwav(stream)
            end
            open(reference_flac) do stream
                @test !LibSndFile.detectwav(stream)
            end
        end
        @testset "WAV file reading" begin
            buf = load(reference_wav)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf, reference_buf) < 1e-10
        end

        @testset "Reading different sample types" begin
            buf = load(reference_wav)
            @test eltype(buf) == Fixed{Int16, 15}

            buf_float = load(reference_wav_float)
            @test eltype(buf_float) == Float32
            @test mse(buf_float, reference_buf) < 1e-10

            buf_double = load(reference_wav_double)
            @test eltype(buf_double) == Float64
            @test mse(buf_double, reference_buf) < 1e-10

            buf_pcm24 = load(reference_wav_pcm24)
            @test eltype(buf_pcm24) == Fixed{Int32, 31}
            @test mse(buf_pcm24, reference_buf) < 1e-10
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
            # lossy compression, so relax the accuracy a bit
            @test mse(buf, reference_buf) < 1e-5
        end

        @testset "Streaming reading" begin
            str = loadstream(reference_wav)
            @test mse(read(str, 50), reference_buf[1:50, :]) < 1e-10
            @test mse(read(str, 50), reference_buf[51:100, :]) < 1e-10
            close(str)
        end

        @testset "WAV file writing" begin
            fname = string(tempname(), ".wav")
            testbuf = TimeSampleBuf(rand(100, 2)-0.5, srate)
            save(fname, testbuf)
            buf = load(fname)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf, testbuf) < 1e-10
        end

        @testset "OGG file writing" begin
            fname = string(tempname(), ".ogg")
            testbuf = TimeSampleBuf(rand(100, 2)-0.5, srate)
            save(fname, testbuf)
            buf = load(fname)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            # noise doesn't compress very well...
            @test mse(buf, testbuf) < 0.05
        end

        @testset "FLAC file writing" begin
            fname = string(tempname(), ".flac")
            # TODO: this conversion fails sometimes because of FixedPointNumbers.jl#37
            arr = convert(Array{Fixed{Int16, 15}}, rand(100, 2)-0.5)
            testbuf = TimeSampleBuf(arr, srate)
            save(fname, testbuf)
            buf = load(fname)
            @test samplerate(buf) == srate
            @test nchannels(buf) == 2
            @test nframes(buf) == 100
            @test domain(buf) == collect(0:99)/srate * s
            @test mse(buf, testbuf) < 1e-10
        end

        @testset "Writing $T data" for T in [Fixed{Int16, 15}, Fixed{Int32, 31}, Float32, Float64]
            fname = string(tempname(), ".wav")
            arr = convert(Array{T}, rand(100, 2)-0.5)
            testbuf = TimeSampleBuf(arr, srate)
            save(fname, testbuf)
            buf = load(fname)
            @test eltype(buf) == T
            @test mse(buf, testbuf) < 1e-10
        end

        @testset "Write errors" begin
            testbuf = TimeSampleBuf(rand(Float32, 100, 2)-0.5, srate)
            flacname = string(tempname(), ".flac")
            redirect_stderr() do rd, wr
                @test_throws ErrorException save(abspath(joinpath("does", "not", "exist.wav")), testbuf)
                @test_throws ErrorException save(flacname, testbuf)
            end
        end

        @testset "Streaming writing" begin
            fname = string(tempname(), ".wav")
            testbuf = TimeSampleBuf(rand(Float32, 100, 2)-0.5, srate)
            # set up a 2-channel Float32 stream
            stream = savestream(fname, 2, srate, Float32)
            write(stream, testbuf[1:50, :])
            write(stream, testbuf[51:100, :])
            close(stream)
            buf = load(fname)
            @test mse(buf, testbuf) < 1e-10
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
    end
catch err
    exit(-1)
end
