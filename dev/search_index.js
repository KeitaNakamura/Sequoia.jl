var documenterSearchIndex = {"docs":
[{"location":"getting_started/#Getting-Started","page":"Getting Started","title":"Getting Started","text":"","category":"section"},{"location":"getting_started/","page":"Getting Started","title":"Getting Started","text":"using Sequoia\nimport Plots\n\n# material constants\nE = 500                    # Young's modulus\nν = 0.3                    # Poisson's ratio\nλ = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter\nμ = E / 2(1 + ν)           # shear modulus\nρ = 1000                   # density\nr = 0.2                    # radius of disk\n\n# properties for grid and particles\nGridProp = @NamedTuple begin\n    x  :: Vec{2, Float64}\n    m  :: Float64\n    mv :: Vec{2, Float64}\n    f  :: Vec{2, Float64}\n    v  :: Vec{2, Float64}\n    vⁿ :: Vec{2, Float64}\nend\nParticleProp = @NamedTuple begin\n    x  :: Vec{2, Float64}\n    m  :: Float64\n    V  :: Float64\n    v  :: Vec{2, Float64}\n    ∇v :: SecondOrderTensor{2, Float64, 4}\n    σ  :: SymmetricSecondOrderTensor{2, Float64, 3}\nend\n\n# background grid\ngrid = generate_grid(GridProp, CartesianMesh(0.05, (0,1), (0,1)))\n\n# particles\nparticles = let\n    pts = generate_particles(ParticleProp, grid.x; alg=GridSampling())\n    pts.V .= prod(grid.x[end]-grid.x[1]) / length(pts)\n\n    # left disk\n    lhs = filter(pts) do pt\n        x, y = pt.x\n        (x-r)^2 + (y-r)^2 < r^2\n    end\n\n    # right disk\n    s = 1-r\n    rhs = filter(pts) do pt\n        x, y = pt.x\n        (x-s)^2 + (y-s)^2 < r^2\n    end\n\n    lhs.v .= Vec( 0.1, 0.1)\n    rhs.v .= Vec(-0.1,-0.1)\n    \n    [lhs; rhs]\nend\n@. particles.m = ρ * particles.V\n\n# use `LinearBSpline` interpolation\nmpvalues = [MPValues(Vec{2}, LinearBSpline()) for _ in 1:length(particles)]\n\n# plot results by `Plots.@gif`\nΔt = 0.001\nPlots.@gif for t in range(0, 4-Δt, step=Δt)\n\n    # update interpolation values\n    for (pt, mp) in zip(particles, mpvalues)\n        update!(mp, pt, grid.x)\n    end\n\n    @P2G grid=>i particles=>p mpvalues=>ip begin\n        m[i]  = @∑ N[ip] * m[p]\n        mv[i] = @∑ N[ip] * m[p] * v[p]\n        f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n        vⁿ[i] = mv[i] / m[i]\n        v[i]  = vⁿ[i] + Δt * (f[i]/m[i])\n    end\n\n    @G2P grid=>i particles=>p mpvalues=>ip begin\n        v[p] += @∑ (v[i] - vⁿ[i]) * N[ip]\n        ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n        x[p] += @∑ Δt * v[i] * N[ip]\n    end\n\n    for p in 1:length(particles)\n        Δϵ = Δt * symmetric(particles.∇v[p])\n        Δσ = λ*tr(Δϵ)*I + 2μ*Δϵ\n        particles.V[p] *= 1 + tr(Δϵ)\n        particles.σ[p] += Δσ\n    end\n\n    # plot results\n    Plots.scatter(\n        reinterpret(Tuple{Float64,Float64}, particles.x),\n        lims = (0,1),\n        ticks = 0:0.2:1,\n        minorgrid = true,\n        minorticks = 4,\n        aspect_ratio = :equal,\n        legend = false,\n    )\nend every 100","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"EditURL = \"../../literate/examples/elastic_impact.jl\"","category":"page"},{"location":"examples/elastic_impact/#Transfer-schemes","page":"Transfer schemes","title":"Transfer schemes","text":"","category":"section"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"<video autoplay muted loop playsinline controls width=\"500\" src=\"https://github.com/KeitaNakamura/Sequoia.jl/assets/16015926/adeb872b-036f-4ba8-8915-0b9c6cf331fc\"/></video>","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"In this example, the following transfer schemes are demonstrated:","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"PIC–FLIP mixed transfer[1]\nAffine PIC (APIC) transfer[2]\nTaylor PIC (TPIC) transfer[3]","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"The problem evolves the elastic impact between two rings, which is consistent with previous studies[4][5].","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[1]: Zhu, Y. and Bridson, R., 2005. Animating sand as a fluid. ACM Transactions on Graphics (TOG), 24(3), pp.965-972.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[2]: Jiang, C., Schroeder, C., Selle, A., Teran, J. and Stomakhin, A., 2015. The affine particle-in-cell method. ACM Transactions on Graphics (TOG), 34(4), pp.1-10.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[3]: Nakamura, K., Matsumura, S. and Mizutani, T., 2023. Taylor particle-in-cell transfer and kernel correction for material point method. Computer Methods in Applied Mechanics and Engineering, 403, p.115720.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[4]: de Vaucorbeil, A. and Nguyen, V.P., 2020. A numerical evaluation of the material point method for slid mechanics problems.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[5]: Huang, P., Zhang, X., Ma, S. and Huang, X., 2011. Contact algorithms for the material point method in impact and penetration simulation. International journal for numerical methods in engineering, 85(4), pp.498-517.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"using Sequoia\n\nabstract type Transfer end\nstruct FLIP <: Transfer α::Float64 end\nstruct APIC <: Transfer end\nstruct TPIC <: Transfer end\n\nfunction elastic_impact(transfer::Transfer = FLIP(1.0))\n\n    # simulation parameters\n    CFL    = 0.8    # Courant number\n    Δx     = 1.0e-3 # grid spacing\n    t_stop = 4e-3   # simulation stops at t=t_stop\n\n    # material constants\n    K  = 121.7e6 # Bulk modulus\n    μ  = 26.1e6  # Shear modulus\n    λ  = K-2μ/3  # Lame's first parameter\n    ρ⁰ = 1.01e3  # initial density\n\n    # geometry\n    L  = 0.2  # length of domain\n    W  = 0.15 # width of domain\n    rᵢ = 0.03 # inner radius of rings\n    rₒ = 0.04 # outer radius of rings\n\n    # properties for grid and particles\n    GridProp = @NamedTuple begin\n        x   :: Vec{2, Float64}\n        m   :: Float64\n        m⁻¹ :: Float64\n        mv  :: Vec{2, Float64}\n        f   :: Vec{2, Float64}\n        v   :: Vec{2, Float64}\n        vⁿ  :: Vec{2, Float64}\n    end\n    ParticleProp = @NamedTuple begin\n        x  :: Vec{2, Float64}\n        m  :: Float64\n        V⁰ :: Float64\n        V  :: Float64\n        v  :: Vec{2, Float64}\n        ∇v :: SecondOrderTensor{2, Float64, 4}\n        σ  :: SymmetricSecondOrderTensor{2, Float64, 3}\n        F  :: SecondOrderTensor{2, Float64, 4}\n        B  :: SecondOrderTensor{2, Float64, 4} # for APIC\n    end\n\n    # background grid\n    grid = generate_grid(GridProp, CartesianMesh(Δx, (-L/2,L/2), (-W/2,W/2)))\n\n    # particles\n    particles = let\n        pts = generate_particles(ParticleProp, grid.x)\n        pts.V⁰ .= prod(grid.x[end]-grid.x[1]) / length(pts)\n\n        lhs = filter(pts) do pt\n            x, y = pt.x\n            rᵢ^2 < (x+L/4)^2+y^2 < rₒ^2\n        end\n        rhs = filter(pts) do pt\n            x, y = pt.x\n            rᵢ^2 < (x-L/4)^2+y^2 < rₒ^2\n        end\n\n        # set initial velocity\n        @. lhs.v =  Vec(30, 0)\n        @. rhs.v = -Vec(30, 0)\n\n        [lhs; rhs]\n    end\n\n    @. particles.V = particles.V⁰\n    @. particles.m = ρ⁰ * particles.V⁰\n    @. particles.F = one(particles.F)\n    @show length(particles)\n\n    # use quadratic B-spline\n    mpvalues = map(eachindex(particles)) do p\n        MPValues(Vec{2, Float64}, QuadraticBSpline())\n    end\n\n    # material model (neo-Hookean)\n    function caucy_stress(F)\n        b = F ⋅ F'\n        J = det(F)\n        (μ*(b-I) + λ*log(J)*I) / J\n    end\n\n    # outputs\n    outdir = mkpath(joinpath(\"output.tmp\", \"elastic_impact\"))\n    pvdfile = joinpath(outdir, \"paraview\")\n    closepvd(openpvd(pvdfile)) # create file\n\n    t = 0.0\n    step = 0\n    fps = 12e3\n    savepoints = collect(LinRange(t, t_stop, round(Int, t_stop*fps)+1))\n\n    Sequoia.@showprogress while t < t_stop\n\n        # calculate timestep based on the wave speed of elastic material\n        Δt = CFL * spacing(grid) / maximum(LazyRows(particles)) do pt\n            ρ = pt.m / pt.V\n            vc = √((λ+2μ) / ρ)\n            vc + norm(pt.v)\n        end\n\n        # update MPValues\n        for p in eachindex(particles, mpvalues)\n            update!(mpvalues[p], LazyRow(particles, p), grid.x)\n        end\n\n        if transfer isa FLIP\n            @P2G grid=>i particles=>p mpvalues=>ip begin\n                m[i]  = @∑ N[ip] * m[p]\n                mv[i] = @∑ N[ip] * m[p] * v[p]\n                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n            end\n        elseif transfer isa APIC\n            local Dₚ⁻¹ = inv(1/4 * Δx^2 * I)\n            @P2G grid=>i particles=>p mpvalues=>ip begin\n                m[i]  = @∑ N[ip] * m[p]\n                mv[i] = @∑ N[ip] * m[p] * (v[p] + B[p] ⋅ Dₚ⁻¹ ⋅ (x[i] - x[p]))\n                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n            end\n        elseif transfer isa TPIC\n            @P2G grid=>i particles=>p mpvalues=>ip begin\n                m[i]  = @∑ N[ip] * m[p]\n                mv[i] = @∑ N[ip] * m[p] * (v[p] + ∇v[p] ⋅ (x[i] - x[p]))\n                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n            end\n        end\n\n        @. grid.m⁻¹ = inv(grid.m) * !iszero(grid.m)\n        @. grid.vⁿ = grid.mv * grid.m⁻¹\n        @. grid.v  = grid.vⁿ + Δt * grid.f * grid.m⁻¹\n\n        if transfer isa FLIP\n            local α = transfer.α\n            @G2P grid=>i particles=>p mpvalues=>ip begin\n                v[p]  = @∑ ((1-α)*v[i] + α*(v[p] + (v[i]-vⁿ[i]))) * N[ip]\n                ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n                x[p] += @∑ Δt * v[i] * N[ip]\n\n            end\n        elseif transfer isa APIC\n            @G2P grid=>i particles=>p mpvalues=>ip begin\n                v[p]  = @∑ v[i] * N[ip]\n                ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n                B[p]  = @∑ v[i] ⊗ (x[i]-x[p]) * N[ip]\n                x[p] += Δt * v[p]\n            end\n        elseif transfer isa TPIC\n            @G2P grid=>i particles=>p mpvalues=>ip begin\n                v[p]  = @∑ v[i] * N[ip]\n                ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n                x[p] += Δt * v[p]\n            end\n        end\n\n        # update other particle properties\n        for pt in LazyRows(particles)\n            ∇u = Δt * pt.∇v\n            F = (I + ∇u) ⋅ pt.F\n            σ = caucy_stress(F)\n            pt.σ = σ\n            pt.F = F\n            pt.V = det(F) * pt.V⁰\n        end\n\n        t += Δt\n        step += 1\n\n        if t > first(savepoints)\n            popfirst!(savepoints)\n            openpvd(pvdfile; append=true) do pvd\n                openvtm(string(pvdfile, step)) do vtm\n                    function stress3x3(F)\n                        z = zero(Mat{2,1})\n                        F3x3 = [F  z\n                                z' 1]\n                        caucy_stress(F3x3)\n                    end\n                    openvtk(vtm, particles.x) do vtk\n                        vtk[\"velocity\"] = particles.v\n                        vtk[\"von Mises\"] = @. vonmises(stress3x3(particles.F))\n                    end\n                    openvtk(vtm, grid.x) do vtk\n                        vtk[\"velocity\"] = grid.v\n                    end\n                    pvd[t] = vtm\n                end\n            end\n        end\n    end\nend","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"This page was generated using Literate.jl.","category":"page"},{"location":"#Sequoia","page":"Home","title":"Sequoia","text":"","category":"section"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"EditURL = \"../../literate/examples/tlmpm_vortex.jl\"","category":"page"},{"location":"examples/tlmpm_vortex/#Total-Lagrangian-MPM","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"","category":"section"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"<video autoplay muted loop playsinline controls width=\"300\" src=\"https://github.com/KeitaNakamura/Sequoia.jl/assets/16015926/81d2c7a1-d0fc-4122-bd3c-0bc8f73ca3fa\"/></video>","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"This example demonstrates the total lagrangian material point method[1]. The implementation solves generalized vortex problem[1] using a linear kernel.","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"note: Note\nCurrently, the Bernstein function used in the paper[1] has not been implemented.","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"[1]: de Vaucorbeil, A., Nguyen, V.P. and Hutchinson, C.R., 2020. A Total-Lagrangian Material Point Method for solid mechanics problems involving large deformations. Computer Methods in Applied Mechanics and Engineering, 360, p.112783.","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"using Sequoia\n\nfunction tlmpm_vortex()\n\n    # simulation parameters\n    CFL    = 0.1  # Courant number\n    Δx     = 0.02 # grid spacing\n    t_stop = 1.0  # simulation stops at t=t_stop\n    α      = 0.99 # PIC-FLIP parameter\n\n    # material constants\n    E  = 1e6                    # Young's modulus\n    ν  = 0.3                    # Poisson's ratio\n    λ  = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter\n    μ  = E / 2(1 + ν)           # shear modulus\n    ρ⁰ = 1e3                    # initial density\n\n    # geometry\n    Rᵢ = 0.75\n    Rₒ = 1.25\n\n    # equations for vortex\n    G = π\n    T = 1.0\n    R̄ = (Rᵢ + Rₒ) / 2\n    function calc_b_Rθ(R, t)\n        h′′, h′, h = hessian(R -> 1-8((R-R̄)/(Rᵢ-Rₒ))^2+16((R-R̄)/(Rᵢ-Rₒ))^4, R, :all)\n        g′′, g′, g = hessian(t -> G*sin(π*t/T), t, :all)\n        β = g * h\n        b_R = ( μ/ρ⁰*(3g*h′+R*g*h′′) - R*g′′*h)*sin(β) + (μ/ρ⁰*R*(g*h′)^2 - R*(g′*h)^2)*cos(β)\n        b_θ = (-μ/ρ⁰*(3g*h′+R*g*h′′) + R*g′′*h)*cos(β) + (μ/ρ⁰*R*(g*h′)^2 + R*(g′*h)^2)*sin(β)\n        Vec(b_R, b_θ)\n    end\n    isinside(x::Vec) = Rᵢ^2 < x⋅x < Rₒ^2\n\n    # properties for grid and particles\n    GridProp = @NamedTuple begin\n        X    :: Vec{2, Float64}\n        m    :: Float64\n        m⁻¹  :: Float64\n        mv   :: Vec{2, Float64}\n        fint :: Vec{2, Float64}\n        fext :: Vec{2, Float64}\n        b    :: Vec{2, Float64}\n        v    :: Vec{2, Float64}\n        vⁿ   :: Vec{2, Float64}\n    end\n    ParticleProp = @NamedTuple begin\n        x  :: Vec{2, Float64}\n        X  :: Vec{2, Float64}\n        m  :: Float64\n        V⁰ :: Float64\n        v  :: Vec{2, Float64}\n        ṽ  :: Vec{2, Float64}\n        ã  :: Vec{2, Float64}\n        P  :: SecondOrderTensor{2, Float64, 4}\n        F  :: SecondOrderTensor{2, Float64, 4}\n    end\n\n    # background grid\n    grid = generate_grid(GridProp, CartesianMesh(Δx, (-1.5,1.5), (-1.5,1.5)))\n    outside_gridinds = findall(!isinside, grid.X)\n\n    # particles\n    particles = generate_particles(ParticleProp, grid.X; alg=GridSampling(), spacing=1)\n    particles.V⁰ .= prod(grid.X[end]-grid.X[1]) / length(particles)\n\n    filter!(pt->isinside(pt.x), particles)\n\n    @. particles.X = particles.x\n    @. particles.m = ρ⁰ * particles.V⁰\n    @. particles.F = one(particles.F)\n    @show length(particles)\n\n    # precompute linear kernel values\n    mpvalues = map(eachindex(particles)) do p\n        mp = MPValues(Vec{2}, LinearBSpline())\n        update!(mp, particles[p], grid.X)\n        mp\n    end\n\n    # outputs\n    outdir = mkpath(joinpath(\"output.tmp\", \"tlmpm_vortex\"))\n    pvdfile = joinpath(outdir, \"paraview\")\n    closepvd(openpvd(pvdfile)) # create file\n\n    t::Float64 = 0.0\n    step::Int = 0\n    fps = 60\n    savepoints = collect(LinRange(t, t_stop, round(Int, t_stop*fps)+1))\n\n    Sequoia.@showprogress while t < t_stop\n\n        # calculate timestep based on the wave speed of elastic material\n        Δt = CFL * spacing(grid) / maximum(LazyRows(particles)) do pt\n            ρ = pt.m / (pt.V⁰ * det(pt.F))\n            vc = √((λ+2μ) / ρ)\n            vc + norm(pt.v)\n        end\n\n        # compute grid body forces\n        for i in eachindex(grid)\n            if isinside(grid.X[i])\n                (x, y) = grid.X[i]\n                R = sqrt(x^2 + y^2)\n                θ = atan(y, x)\n                grid.b[i] = rotmat(θ) ⋅ calc_b_Rθ(R, t)\n            end\n        end\n\n        @P2G grid=>i particles=>p mpvalues=>ip begin\n            m[i]    = @∑ N[ip] * m[p]\n            mv[i]   = @∑ N[ip] * m[p] * v[p]\n            fint[i] = @∑ -V⁰[p] * P[p] ⋅ ∇N[ip]\n        end\n\n        @. grid.m⁻¹  = inv(grid.m) * !iszero(grid.m)\n        @. grid.fext = grid.m * grid.b\n        @. grid.vⁿ   = grid.mv * grid.m⁻¹\n        @. grid.v    = grid.vⁿ + Δt * (grid.fint + grid.fext) * grid.m⁻¹\n        grid.v[outside_gridinds] .= zero(eltype(grid.v))\n\n        # update particle velocity and position\n        @G2P grid=>i particles=>p mpvalues=>ip begin\n            ṽ[p]  = @∑ v[i] * N[ip]\n            ã[p]  = @∑ (v[i] - vⁿ[i])/Δt * N[ip]\n            v[p]  = (1-α)*ṽ[p] + α*(v[p] + Δt*ã[p])\n            x[p] += Δt * ṽ[p]\n        end\n\n        # remap updated velocity to grid (MUSL)\n        @P2G grid=>i particles=>p mpvalues=>ip begin\n            mv[i] = @∑ N[ip] * m[p] * v[p]\n            v[i]  = mv[i] * m⁻¹[i]\n        end\n        grid.v[outside_gridinds] .= zero(eltype(grid.v))\n\n        # update stress\n        @G2P grid=>i particles=>p mpvalues=>ip begin\n            F[p] += @∑ Δt * v[i] ⊗ ∇N[ip]\n            P[p]  = μ * (F[p] - inv(F[p])') + λ * log(det(F[p])) * inv(F[p])'\n        end\n\n        t += Δt\n        step += 1\n\n        if t > first(savepoints)\n            popfirst!(savepoints)\n            openpvd(pvdfile; append=true) do pvd\n                openvtm(string(pvdfile, step)) do vtm\n                    angle(x) = atan(x[2], x[1])\n                    openvtk(vtm, particles.x) do vtk\n                        vtk[\"velocity\"] = particles.v\n                        vtk[\"initial angle\"] = angle.(particles.X)\n                    end\n                    openvtk(vtm, grid.X) do vtk\n                        vtk[\"external force\"] = grid.fext\n                    end\n                    pvd[t] = vtm\n                end\n            end\n        end\n    end\nend","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"This page was generated using Literate.jl.","category":"page"}]
}
