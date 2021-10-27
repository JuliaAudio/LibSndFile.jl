arr = map(PCM16Sample, rand(100, 2) .- 0.5)
testbuf = SampleBuf(arr, srate)
for ext in extensions 
  fname = string(tempname(), ext)
  FileIO.save(fname, testbuf)
  buf = FileIO.load(fname)
  @test buf isa SampleBuf
end

if !Sys.iswindows()
  # testing with unicode
  file = joinpath(tempdir(),"α.flac")
  FileIO.save(file, testbuf)
  FileIO.load(file)
end
