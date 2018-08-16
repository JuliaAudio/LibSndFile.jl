VERSION >= v"0.7.0-" && using InteractiveUtils
versioninfo()

if VERSION < v"0.7.0-"
    Pkg.clone(pwd(), "LibSndFile")
    Pkg.build("LibSndFile")
    # for now we need SampledSignals master
    Pkg.checkout("SampledSignals")
else
    using Pkg
    # for now we need to `clone` because there's no way to specify the
    # package name for `add`
    Pkg.clone(pwd(), "LibSndFile")
    Pkg.build("LibSndFile")
    Pkg.add(PackageSpec(name="SampledSignals", rev="master"))
end
# manually install test dependencies so we can run the test script directly, which avoids
# clobberling our environment
Pkg.add("Compat")
Pkg.add("FileIO")
