@testset "Sink Display" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 10000, 2) .- 0.5f0, srate)
    # set up a 2-channel Float32 stream
    stream = savestreaming_wav(fname, 2, srate, Float32)
    io = IOBuffer()
    show(io, stream)
    @test replace(String(take!(io)), " " => "") == 
    replace(
    """
    LibSndFile.SndFileSink{Float32, String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 0 of 0 frames
                0.00 of 0.00 seconds"""
    , " " => "")
    write(stream, testbuf)
    show(io, stream)
    @test replace(String(take!(io)), " " => "") == 
    replace(
    """
    LibSndFile.SndFileSink{Float32, String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 10000 of 10000 frames
                0.23 of 0.23 seconds"""
    , " " => "")
end

@testset "Source Display" begin
    fname = string(tempname(), ".wav")
    testbuf = SampleBuf(rand(Float32, 10000, 2) .- 0.5f0, srate)
    save_wav(fname, testbuf)
    # set up a 2-channel Float32 stream
    stream = loadstreaming_wav(fname)
    io = IOBuffer()
    show(io, stream)
    @test replace(String(take!(io)), " " => "") == 
    replace(
    """
    LibSndFile.SndFileSource{Float32, String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 0 of 10000 frames
                0.00 of 0.23 seconds"""
    , " " => "")
    read(stream, 5000)
    show(io, stream)
    @test replace(String(take!(io)), " " => "") == 
    replace(
    """
    LibSndFile.SndFileSource{Float32, String}
      path: "$fname"
      channels: 2
      samplerate: 44100Hz
      position: 5000 of 10000 frames
                0.11 of 0.23 seconds"""
    , " " => "")
end
