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
