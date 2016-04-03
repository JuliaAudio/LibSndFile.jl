using BinDeps

@BinDeps.setup

ENV["JULIA_ROOT"] = abspath(JULIA_HOME, "../../")

# include alias for WinRPM library
libsndfile = library_dependency("libsndfile", aliases=["libsndfile-1"])

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
