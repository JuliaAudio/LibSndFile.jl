#!/usr/bin/env julia
using Test
using FileIO
using LibSndFile
using SampledSignals
using LinearAlgebra

extensions = (".wav", 
              ".ogg", 
              ".flac")

formats = [
           ("_wav", format"WAV"),
           ("_ogg", format"OGG"), 
           ("_flac", format"FLAC"),
          ]

include("utils.jl")

@testset "LibSndFile Tests" begin
  @testset "Version" begin
    v = LibSndFile.version()
    @test v[1:10] == "libsndfile"
  end
  @testset "File reading" begin
    include("file_reading.jl")
  end
  @testset "Streaming and IO" begin
    include("stream.jl")
  end
  @testset "File writing" begin
    include("file_writing.jl")
  end
  @testset "FileIO Integration" begin
    include("fileio.jl")
  end
  @testset "Display" begin
    include("display.jl")
  end

  # TODO: check out what happens when samplerate, channels, etc. are wrong
  # when reading/writing
end
