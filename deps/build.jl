using BinDeps

@BinDeps.setup

ENV["JULIA_ROOT"] = abspath(Sys.BINDIR, "../../")

# include alias for WinRPM library
libsndfile = library_dependency("libsndfile", aliases=["libsndfile-1"])

provides(AptGet, "libsndfile1-dev", libsndfile)
provides(Pacman, "libsndfile", libsndfile)

@static if Sys.isapple()
    using Homebrew
    provides(Homebrew.HB, "libsndfile", libsndfile)
end

@static if Sys.iswindows()
    using WinRPM
    provides(WinRPM.RPM, "libsndfile1", libsndfile, os = :Windows)
end

@BinDeps.install Dict(:libsndfile => :libsndfile)
