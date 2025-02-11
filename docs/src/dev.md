# Development Documentation

The core of `FastTransforms.jl` is developed in parallel with the [C library](https://github.com/MikaelSlevinsky/FastTransforms) of the same name. Julia and C interoperability is enhanced by the [BinaryBuilder](https://github.com/JuliaPackaging/BinaryBuilder.jl) infrastructure, which provides the user a safe and seamless experience using a package in a different language.

## Why two packages?

Orthogonal polynomial transforms are performance-sensitive imperative tasks. Yet, many of Julia's rich and evolving language features are simply unnecessary for defining these computational routines. Moreover, rapid language changes in Julia (as compared to C) have been more than a perturbation to this repository in the past.

The C library generates assembly for vectorized operations such as single instruction multiple data (SIMD) that is more efficient than that generated by a compiler without human intervention. It also uses OpenMP to introduce shared memory parallelism for large tasks. Finally, calling into precompiled binaries reduces the Julia package's pre-compilation and dependencies, improving the user experience. Some of these capabilities also exist in Julia, but with C there is frankly more control over performance.

C libraries are easier to call from any other language, partly explaining why the Python package manager Spack [already supports the C library](https://spack.readthedocs.io/en/latest/package_list.html#fasttransforms) through third-party efforts.

In Julia, a parametric composite type with unrestricted type parameters is just about as big as `Any`. Such a type allows the Julia API to far exceed the C API in its ability to unify all of the orthogonal polynomial transforms and present them as linear operators. The `mutable struct FTPlan{T, N, K}`, together with `AdjointFTPlan` and `TransposeFTPlan`, are the core Julia types in this repository. Whereas `T` is understood to represent element type of the plan and `N` represents the number of leading dimensions of the array on which it operates, `K` is a mere integer which serves to distinguish the orthogonal polynomials at play. For example, `FTPlan{Float64, 1, LEG2CHEB}` represents the necessary pre-computations to convert 64-bit Legendre series to Chebyshev series (of the first kind). `N == 1` because Chebyshev and Legendre series are naturally represented with vectors of coefficients. However, this particular plan may operate not only on vectors but also on matrices, column-by-column.

!!! note
    When working with specialized `FTPlan`s, it is prudent to use the named constants for `K`, such as `FastTransforms.LEG2CHEB`, rather than their literal integer values as these may change when future plans become operational.

## The developer's right to build from source

Precompiled binaries are important for users, but development in C may be greatly accelerated by coupling it with a dynamic language such as Julia. For this reason, the repository preserves the developer's right to build the C library from source by setting an environment variable to trigger the build script:

```julia
julia> ENV["FT_BUILD_FROM_SOURCE"] = "true"
"true"

(@v1.5) pkg> build FastTransforms
   Building FFTW ──────────→ `~/.julia/packages/FFTW/ayqyZ/deps/build.log`
   Building TimeZones ─────→ `~/.julia/packages/TimeZones/K98G0/deps/build.log`
   Building FastTransforms → `~/.julia/dev/FastTransforms/deps/build.log`

julia> using FastTransforms
[ Info: Precompiling FastTransforms [057dd010-8810-581a-b7be-e3fc3b93f78c]

```

This lets the developer experiment with new features through `ccall`ing into bleeding edge source code. Customizing the build script further allows the developer to track a different branch or even a fork.

## From release to release to release

To get from a C library release to a Julia package release, the developer needs to update Yggdrasil's [build_tarballs.jl](https://github.com/JuliaPackaging/Yggdrasil/blob/master/F/FastTransforms/build_tarballs.jl) script for the new version and its 256-bit SHA. On macOS, the SHA can be found by:

```julia
shell> curl https://codeload.github.com/MikaelSlevinsky/FastTransforms/tar.gz/v0.6.0 --output FastTransforms.tar.gz
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  162k    0  162k    0     0   252k      0 --:--:-- --:--:-- --:--:--  252k

shell> shasum -a 256 FastTransforms.tar.gz
ae2db2fa808ca17c5dc5ac25b079eba2dbe598d061b9b4e14c948680870abc3c  FastTransforms.tar.gz

shell> rm -f FastTransforms.tar.gz

```

Using [SHA.jl](https://github.com/JuliaCrypto/SHA.jl), the SHA can also be found by:

```julia
shell> curl https://codeload.github.com/MikaelSlevinsky/FastTransforms/tar.gz/v0.6.0 --output FastTransforms.tar.gz
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  156k    0  156k    0     0   443k      0 --:--:-- --:--:-- --:--:--  443k

julia> using SHA

julia> open("FastTransforms.tar.gz") do f
           bytes2hex(sha256(f))
       end
"ae2db2fa808ca17c5dc5ac25b079eba2dbe598d061b9b4e14c948680870abc3c"

shell> rm -f FastTransforms.tar.gz

```

Then we wait for the friendly folks at [JuliaPackaging](https://github.com/JuliaPackaging) to merge the pull request to Yggdrasil, triggering a new release of the [FastTransforms_jll.jl](https://github.com/JuliaBinaryWrappers/FastTransforms_jll.jl) meta package that stores all precompiled binaries. With this release, we update the FastTransforms.jl [Project.toml](https://github.com/JuliaApproximation/FastTransforms.jl/blob/master/Project.toml) to point to the latest release and register the new version.

Since development of Yggdrasil is quite rapid, a fork may easily become stale. Git permits the developer to forcibly make a master branch on a fork even with upstream master:

```
git fetch upstream
git checkout master
git reset --hard upstream/master
git push origin master --force
```
