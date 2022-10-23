@testset "BSplineValue" begin
    for T in (Float32, Float64)
        Random.seed!(1234)
        TOL = sqrt(eps(T))
        for dim in 1:3
            grid = Grid(ntuple(i -> 0:0.1:1, Val(dim)))
            for bspline in (LinearBSpline(), QuadraticBSpline(), CubicBSpline(),)
                mp = MPValue{dim, T}(bspline)
                for _ in 1:2000
                    x = rand(Vec{dim, T})
                    update!(mp, grid, x)
                    @test sum(mp.N) ≈ 1
                    @test sum(mp.∇N) ≈ zero(Vec{dim}) atol=TOL
                    l = Marble.get_supportlength(bspline)
                    if all(a->l<a<1-l, x)
                        @test grid_to_point((mp,i) -> mp.N*grid[i], mp) ≈ x atol=TOL
                        @test grid_to_point((mp,i) -> grid[i]⊗mp.∇N, mp) ≈ I atol=TOL
                    end
                end
            end
        end
    end
end

@testset "WLSValue" begin
    for T in (Float32, Float64)
        Random.seed!(1234)
        TOL = sqrt(eps(T))
        for dim in 1:3
            grid = Grid(ntuple(i -> 0.0:0.1:1.0, Val(dim)))
            side_length = gridsteps(grid) ./ 2
            r = Vec(side_length ./ 2)
            for kernel in (QuadraticBSpline(), CubicBSpline(), GIMP())
                for WLS in (LinearWLS, Marble.BilinearWLS)
                    WLS == Marble.BilinearWLS && dim != 2 && continue
                    mp = MPValue{dim, T}(WLS(kernel))
                    for _ in 1:2000
                        x = rand(Vec{dim, T})
                        if kernel isa GIMP
                            update!(mp, grid, (;x,r))
                        else
                            update!(mp, grid, x)
                        end
                        @test sum(mp.N) ≈ 1
                        @test sum(mp.∇N) ≈ zero(Vec{dim}) atol=TOL
                        @test grid_to_point((mp,i) -> mp.N*grid[i], mp) ≈ x atol=TOL
                        @test grid_to_point((mp,i) -> grid[i]⊗mp.∇N, mp) ≈ I atol=TOL
                    end
                end
            end
        end
    end
end

@testset "GIMPValue" begin
    for T in (Float32, Float64)
        Random.seed!(1234)
        TOL = sqrt(eps(T))
        for dim in 1:3
            grid = Grid(ntuple(i -> 0.0:0.1:1.0, Val(dim)))
            for gimp in (GIMP(),)
                mp = MPValue{dim, T}(gimp)
                side_length = gridsteps(grid) ./ 2
                r = Vec(side_length ./ 2)
                # GIMP doesn't have pertition of unity when closed to boundaries
                # if we follow eq.40 in Bardenhagen (2004)
                for _ in 1:2000
                    x = rand(Vec{dim, T})
                    if all(a->a[2]<a[1]<1-a[2], zip(x,r))
                        update!(mp, grid, (;x,r))
                        @test sum(mp.N) ≈ 1
                        @test sum(mp.∇N) ≈ zero(Vec{dim}) atol=TOL
                        @test grid_to_point((mp,i) -> mp.N*grid[i], mp) ≈ x atol=TOL
                        @test grid_to_point((mp,i) -> grid[i]⊗mp.∇N, mp) ≈ I atol=TOL
                    end
                end
            end
        end
    end
end

@testset "KernelCorrectionValue" begin
    for T in (Float32, Float64)
        Random.seed!(1234)
        TOL = sqrt(eps(T))
        for dim in 1:3
            grid = Grid(ntuple(i -> 0.0:0.1:1.0, Val(dim)))
            side_length = gridsteps(grid) ./ 2
            r = Vec(side_length ./ 2)
            for kernel in (QuadraticBSpline(), CubicBSpline(), GIMP())
                mp = MPValue{dim, T}(KernelCorrection(kernel))
                for _ in 1:2000
                    x = rand(Vec{dim, T})
                    if kernel isa GIMP
                        update!(mp, grid, (;x,r))
                    else
                        update!(mp, grid, x)
                    end
                    @test sum(mp.N) ≈ 1
                    @test sum(mp.∇N) ≈ zero(Vec{dim}) atol=TOL
                    @test grid_to_point((mp,i) -> mp.N*grid[i], mp) ≈ x atol=TOL
                    @test grid_to_point((mp,i) -> grid[i]⊗mp.∇N, mp) ≈ I atol=TOL
                end
            end
        end
    end
end
