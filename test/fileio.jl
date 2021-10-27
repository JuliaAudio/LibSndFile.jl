arr = map(PCM16Sample, rand(100, 2) .- 0.5)
testbuf = SampleBuf(arr, srate)
for ext in extensions 
  fname = string(tempname(), ext)
  FileIO.save(fname, testbuf)
  buf = FileIO.load(fname)
  @test buf isa SampleBuf
end

# testing with unicode
FileIO.save("β.flac", testbuf)
FileIO.load("β.flac")
rm("β.flac")
