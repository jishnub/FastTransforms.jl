using FastTransforms, Test

FastTransforms.ft_set_num_threads(ceil(Int, Base.Sys.CPU_THREADS/2))

@testset "libfasttransforms" begin
    n = 64
    for T in (Float32, Float64)
        c = one(T) ./ (1:n)
        x = collect(-1 .+ 2*(0:n-1)/T(n))
        f = similar(x)
        @test FastTransforms.horner!(c, x, f) == f
        fd = T[sum(c[k]*x^(k-1) for k in 1:length(c)) for x in x]
        @test f ≈ fd
        @test FastTransforms.clenshaw!(c, x, f) == f
        fd = T[sum(c[k]*cos((k-1)*acos(x)) for k in 1:length(c)) for x in x]
        @test f ≈ fd
        A = T[(2k+one(T))/(k+one(T)) for k in 0:length(c)-1]
        B = T[zero(T) for k in 0:length(c)-1]
        C = T[k/(k+one(T)) for k in 0:length(c)]
        phi0 = ones(T, length(x))
        c = cheb2leg(c)
        @test FastTransforms.clenshaw!(c, A, B, C, x, phi0, f) == f
        @test f ≈ fd
    end

    α, β, γ, δ, λ, μ = 0.1, 0.2, 0.3, 0.4, 0.5, 0.6
    function test_1d_plans(p1, p2, x)
        y = p1*x
        z = p2*y
        @test z ≈ x
        y = p1*x
        z = p1'y
        y = transpose(p1)*z
        z = transpose(p1)\y
        y = p1'\z
        z = p1\y
        @test z ≈ x
        y = p2*x
        z = p2'y
        y = transpose(p2)*z
        z = transpose(p2)\y
        y = p2'\z
        z = p2\y
        @test z ≈ x
        P = p1*I
        Q = p2*P
        @test Q ≈ I
        P = p1*I
        Q = p1'P
        P = transpose(p1)*Q
        Q = transpose(p1)\P
        P = p1'\Q
        Q = p1\P
        @test Q ≈ I
        P = p2*I
        Q = p2'P
        P = transpose(p2)*Q
        Q = transpose(p2)\P
        P = p2'\Q
        Q = p2\P
        @test Q ≈ I
    end

    for T in (Float32, Float64, Complex{Float32}, Complex{Float64}, BigFloat, Complex{BigFloat})
        x = T(1)./(1:n)
        Id = Matrix{T}(I, n, n)
        for (p1, p2) in ((plan_leg2cheb(Id), plan_cheb2leg(Id)),
                         (plan_ultra2ultra(Id, λ, μ), plan_ultra2ultra(Id, μ, λ)),
                         (plan_jac2jac(Id, α, β, γ, δ), plan_jac2jac(Id, γ, δ, α, β)),
                         (plan_lag2lag(Id, α, β), plan_lag2lag(Id, β, α)),
                         (plan_jac2ultra(Id, α, β, λ), plan_ultra2jac(Id, λ, α, β)),
                         (plan_jac2cheb(Id, α, β), plan_cheb2jac(Id, α, β)),
                         (plan_ultra2cheb(Id, λ), plan_cheb2ultra(Id, λ)))
            test_1d_plans(p1, p2, x)
        end
    end

    for T in (Float32, Float64, Complex{Float32}, Complex{Float64})
        x = T(1)./(1:n)
        Id = Matrix{T}(I, n, n)
        p = plan_associatedjac2jac(Id, 1, α, β, γ, δ)
        V = p*I
        @test V ≈ p*Id
        y = p*x
        @test V\y ≈ x
    end

    @testset "Modified classical orthonormal polynomial transforms" begin
        (n, α, β) = (16, 0, 0)
        P1 = plan_modifiedjac2jac(Float64, n, α, β, [0.9428090415820636, -0.32659863237109055, -0.42163702135578396, 0.2138089935299396]) # u1(x) = (1-x)^2*(1+x)
        P2 = plan_modifiedjac2jac(Float64, n, α, β, [0.9428090415820636, -0.32659863237109055, -0.42163702135578396, 0.2138089935299396], [1.4142135623730951]) # u2(x) = (1-x)^2*(1+x)
        P3 = plan_modifiedjac2jac(Float64, n, α, β, [-0.9428090415820636, 0.32659863237109055, 0.42163702135578396, -0.2138089935299396], [-5.185449728701348, 0.0, 0.42163702135578374]) # u3(x) = -(1-x)^2*(1+x), v3(x) = -(2-x)*(2+x)
        P4 = plan_modifiedjac2jac(Float64, n, α+2, β+1, [1.1547005383792517], [4.387862045841156, 0.1319657758147716, -0.20865621238292037]) # v4(x) = (2-x)*(2+x)

        @test P1*I ≈ P2*I
        @test P1\I ≈ P2\I
        @test P3*I ≈ P2*(P4*I)
        @test P3\I ≈ P4\(P2\I)

        P5 = plan_modifiedlag2lag(Float64, n, α, [2.0, -4.0, 2.0]) # u5(x) = x^2
        P6 = plan_modifiedlag2lag(Float64, n, α, [2.0, -4.0, 2.0], [1.0]) # u6(x) = x^2
        P7 = plan_modifiedlag2lag(Float64, n, α, [2.0, -4.0, 2.0], [7.0, -7.0, 2.0]) # u7(x) = x^2, v7(x) = (1+x)*(2+x)
        P8 = plan_modifiedlag2lag(Float64, n, α+2, [sqrt(2.0)], [sqrt(1058.0), -sqrt(726.0), sqrt(48.0)]) # v8(x) = (1+x)*(2+x)

        @test P5*I ≈ P6*I
        @test P5\I ≈ P6\I
        @test P7*I ≈ P6*(P8*I)
        @test P7\I ≈ P8\(P6\I)

        P9 = plan_modifiedherm2herm(Float64, n, [2.995504568550877, 0.0, 3.7655850551068593, 0.0, 1.6305461589167827], [2.995504568550877, 0.0, 3.7655850551068593, 0.0, 1.6305461589167827]) # u9(x) = 1+x^2+x^4, v9(x) = 1+x^2+x^4

        @test P9*I ≈ P9\I
    end

    function test_nd_plans(p, ps, pa, A)
        B = copy(A)
        C = ps*(p*A)
        A = p\(pa*C)
        @test A ≈ B
        C = ps'*(p'A)
        A = p'\(pa'C)
        @test A ≈ B
        C = transpose(ps)*(transpose(p)*A)
        A = transpose(p)\(transpose(pa)*C)
        @test A ≈ B
    end

    A = sphones(Float64, n, 2n-1)
    p = plan_sph2fourier(A)
    ps = plan_sph_synthesis(A)
    pa = plan_sph_analysis(A)
    test_nd_plans(p, ps, pa, A)
    A = sphones(Float64, n, 2n-1) + im*sphones(Float64, n, 2n-1)
    p = plan_sph2fourier(A)
    ps = plan_sph_synthesis(A)
    pa = plan_sph_analysis(A)
    test_nd_plans(p, ps, pa, A)

    A = sphvones(Float64, n, 2n-1)
    p = plan_sphv2fourier(A)
    ps = plan_sphv_synthesis(A)
    pa = plan_sphv_analysis(A)
    test_nd_plans(p, ps, pa, A)
    A = sphvones(Float64, n, 2n-1) + im*sphvones(Float64, n, 2n-1)
    p = plan_sphv2fourier(A)
    ps = plan_sphv_synthesis(A)
    pa = plan_sphv_analysis(A)
    test_nd_plans(p, ps, pa, A)

    A = diskones(Float64, n, 4n-3)
    p = plan_disk2cxf(A, α, β)
    ps = plan_disk_synthesis(A)
    pa = plan_disk_analysis(A)
    test_nd_plans(p, ps, pa, A)
    A = diskones(Float64, n, 4n-3) + im*diskones(Float64, n, 4n-3)
    p = plan_disk2cxf(A, α, β)
    ps = plan_disk_synthesis(A)
    pa = plan_disk_analysis(A)
    test_nd_plans(p, ps, pa, A)

    A = rectdiskones(Float64, n, n)
    p = plan_rectdisk2cheb(A, β)
    ps = plan_rectdisk_synthesis(A)
    pa = plan_rectdisk_analysis(A)
    test_nd_plans(p, ps, pa, A)
    A = rectdiskones(Float64, n, n) + im*rectdiskones(Float64, n, n)
    p = plan_rectdisk2cheb(A, β)
    ps = plan_rectdisk_synthesis(A)
    pa = plan_rectdisk_analysis(A)
    test_nd_plans(p, ps, pa, A)

    A = triones(Float64, n, n)
    p = plan_tri2cheb(A, α, β, γ)
    ps = plan_tri_synthesis(A)
    pa = plan_tri_analysis(A)
    test_nd_plans(p, ps, pa, A)
    A = triones(Float64, n, n) + im*triones(Float64, n, n)
    p = plan_tri2cheb(A, α, β, γ)
    ps = plan_tri_synthesis(A)
    pa = plan_tri_analysis(A)
    test_nd_plans(p, ps, pa, A)

    α, β, γ, δ = -0.1, -0.2, -0.3, -0.4
    A = tetones(Float64, n, n, n)
    p = plan_tet2cheb(A, α, β, γ, δ)
    ps = plan_tet_synthesis(A)
    pa = plan_tet_analysis(A)
    test_nd_plans(p, ps, pa, A)
    A = tetones(Float64, n, n, n) + im*tetones(Float64, n, n, n)
    p = plan_tet2cheb(A, α, β, γ, δ)
    ps = plan_tet_synthesis(A)
    pa = plan_tet_analysis(A)
    test_nd_plans(p, ps, pa, A)

    A = spinsphones(Complex{Float64}, n, 2n-1, 2) + im*spinsphones(Complex{Float64}, n, 2n-1, 2)
    p = plan_spinsph2fourier(A, 2)
    ps = plan_spinsph_synthesis(A, 2)
    pa = plan_spinsph_analysis(A, 2)
    test_nd_plans(p, ps, pa, A)
end
