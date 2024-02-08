var documenterSearchIndex = {"docs":
[{"location":"getting_started/#Getting-Started","page":"Getting Started","title":"Getting Started","text":"","category":"section"},{"location":"getting_started/","page":"Getting Started","title":"Getting Started","text":"using Sequoia\nimport Plots\n\n# material constants\nE = 1000                   # Young's modulus\nν = 0.3                    # Poisson's ratio\nλ = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter\nμ = E / 2(1 + ν)           # shear modulus\nρ = 1000                   # density\nr = 0.2                    # radius of disk\n\n# properties for grid and particles\nGridProp = @NamedTuple begin\n    x  :: Vec{2, Float64}\n    m  :: Float64\n    mv :: Vec{2, Float64}\n    f  :: Vec{2, Float64}\n    v  :: Vec{2, Float64}\n    vⁿ :: Vec{2, Float64}\nend\nParticleProp = @NamedTuple begin\n    x  :: Vec{2, Float64}\n    m  :: Float64\n    V  :: Float64\n    v  :: Vec{2, Float64}\n    ∇v :: SecondOrderTensor{2, Float64, 4}\n    σ  :: SymmetricSecondOrderTensor{2, Float64, 3}\nend\n\n# background grid\ngrid = generate_grid(GridProp, 0.05, (0,1), (0,1))\n\n# particles\nparticles = let\n    pts = generate_particles(ParticleProp, grid.x; alg=GridSampling())\n    pts.V .= prod(grid.x[end]-grid.x[1]) / length(pts)\n\n    # left disk\n    lhs = filter(pts) do pt\n        x, y = pt.x\n        (x-r)^2 + (y-r)^2 < r^2\n    end\n\n    # right disk\n    s = 1-r\n    rhs = filter(pts) do pt\n        x, y = pt.x\n        (x-s)^2 + (y-s)^2 < r^2\n    end\n\n    lhs.v .= Vec( 0.1, 0.1)\n    rhs.v .= Vec(-0.1,-0.1)\n    \n    [lhs; rhs]\nend\n@. particles.m = ρ * particles.V\n\n# use `LinearBSpline` interpolation\nmpvalues = [MPValues(Vec{2}, LinearBSpline()) for _ in 1:length(particles)]\n\n# plot results by `Plots.@gif`\nΔt = 0.001\nPlots.@gif for t in range(0, 4-Δt, step=Δt)\n\n    # update interpolation values\n    for (pt, mp) in zip(particles, mpvalues)\n        update!(mp, pt, grid.x)\n    end\n\n    @P2G grid=>i particles=>p mpvalues=>ip begin\n        m[i]  = @∑ N[ip] * m[p]\n        mv[i] = @∑ N[ip] * m[p] * v[p]\n        f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n        vⁿ[i] = mv[i] / m[i]\n        v[i]  = vⁿ[i] + Δt * (f[i]/m[i])\n    end\n\n    @G2P grid=>i particles=>p mpvalues=>ip begin\n        v[p] += @∑ (v[i] - vⁿ[i]) * N[ip]\n        ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n        x[p] += @∑ Δt * v[i] * N[ip]\n    end\n\n    for p in 1:length(particles)\n        Δϵ = Δt * symmetric(particles.∇v[p])\n        Δσ = λ*tr(Δϵ)*I + 2μ*Δϵ\n        particles.V[p] *= 1 + tr(Δϵ)\n        particles.σ[p] += Δσ\n    end\n\n    # plot results\n    Plots.scatter(\n        reinterpret(Tuple{Float64,Float64}, particles.x),\n        lims = (0,1),\n        ticks = 0:0.2:1,\n        minorgrid = true,\n        minorticks = 4,\n        aspect_ratio = :equal,\n        legend = false,\n    )\nend every 100","category":"page"},{"location":"#Sequoia","page":"Home","title":"Sequoia","text":"","category":"section"}]
}
