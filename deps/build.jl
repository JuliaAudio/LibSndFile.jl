using BinDeps
using Compat.Sys: BINDIR

@BinDeps.setup

ENV["JULIA_ROOT"] = abspath(BINDIR, "../../")

# include alias for WinRPM library
libsndfile = library_dependency("libsndfile", aliases=["libsndfile-1"])

provides(AptGet, "libsndfile1-dev", libsndfile)
provides(Pacman, "libsndfile", libsndfile)

@static if is_apple()
    using Homebrew
    provides(Homebrew.HB, "libsndfile", libsndfile)
end

@static if is_windows()
    using WinRPM
    provides(WinRPM.RPM, "libsndfile1", libsndfile, os = :Windows)
end

@BinDeps.install Dict(:libsndfile => :libsndfile)
