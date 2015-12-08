using BinDeps

@BinDeps.setup

ENV["JULIA_ROOT"] = abspath(JULIA_HOME, "../../")

libsndfile = library_dependency("libsndfile")

# TODO: add other providers with correct names
provides(AptGet, "libsndfile1-dev", libsndfile)
provides(Pacman, "libsndfile", libsndfile)


@osx_only begin
    using Homebrew
    provides(Homebrew.HB, "libsndfile", libsndfile)
end

@windows_only begin
    using WinRPM
    provides(WinRPM.RPM, "libsndfile1", libsndfile, os = :Windows)
end

@BinDeps.install Dict(:libsndfile => :libsndfile)
