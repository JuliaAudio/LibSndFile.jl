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

@testset "Write errors" begin
    testbuf = SampleBuf(rand(Float32, 100, 2) .- 0.5, srate)
    flacname = string(tempname(), ".flac")
    @test_throws ErrorException save_flac(abspath("doesnotexist.wav"), testbuf)
    @test_throws ErrorException save_flac(flacname, testbuf)
end
