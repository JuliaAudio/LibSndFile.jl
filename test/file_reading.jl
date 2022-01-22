@testset "PCM16 WAV file reading" begin
    buf = load_wav(reference_wav)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/(srate))
    @test mse(buf, reference_buf) < 1e-10
    @test eltype(buf) == PCM16Sample
end

@testset "PCM32 WAV file reading" begin
    buf = load_wav(reference_wav_pcm24)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/(srate))
    @test mse(buf, reference_buf) < 1e-10
    @test eltype(buf) == PCM32Sample
end

@testset "Float32 WAV file reading" begin
    buf = load_wav(reference_wav_float)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/(srate))
    @test mse(buf, reference_buf) < 1e-10
    @test eltype(buf) == Float32
end

@testset "Float64 WAV file reading" begin
    buf = load_wav(reference_wav_double)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/(srate))
    @test mse(buf, reference_buf) < 1e-10
    @test eltype(buf) == Float64
end

@testset "FLAC file reading" begin
    buf = load_flac(reference_flac)
    @test samplerate(buf) == srate
    @test nchannels(buf) == 2
    @test nframes(buf) == 100
    @test isapprox(domain(buf), collect(0:99)/srate)
    @test mse(buf, reference_buf) < 1e-10
    @test eltype(buf) == PCM16Sample
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

@testset "Read errors" begin
    @test_throws ErrorException load_wav("doesnotexist.wav")
end
