var documenterSearchIndex = {"docs":
[{"location":"examples/implicit_jacobian_based/","page":"Jacobian-based implicit method","title":"Jacobian-based implicit method","text":"EditURL = \"../../literate/examples/implicit_jacobian_based.jl\"","category":"page"},{"location":"examples/implicit_jacobian_based/#Jacobian-based-implicit-method","page":"Jacobian-based implicit method","title":"Jacobian-based implicit method","text":"","category":"section"},{"location":"examples/implicit_jacobian_based/","page":"Jacobian-based implicit method","title":"Jacobian-based implicit method","text":"using Sequoia\n\nfunction implicit_jacobian_based()\n\n    # Simulation parameters\n    h  = 0.05 # Grid spacing\n    T  = 0.5  # Time span\n    g  = 20.0 # Gravity acceleration\n    Δt = 0.05  # Timestep\n\n    # Material constants\n    E  = 1e6                    # Young's modulus\n    ν  = 0.3                    # Poisson's ratio\n    λ  = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter\n    μ  = E / 2(1 + ν)           # Shear modulus\n    ρ⁰ = 500.0                  # Density\n\n    # Newmark-beta integration\n    β = 1/4\n    γ = 1/2\n\n    GridProp = @NamedTuple begin\n        X   :: Vec{3, Float64}\n        m   :: Float64\n        m⁻¹ :: Float64\n        v   :: Vec{3, Float64}\n        vⁿ  :: Vec{3, Float64}\n        mv  :: Vec{3, Float64}\n        a   :: Vec{3, Float64}\n        aⁿ  :: Vec{3, Float64}\n        ma  :: Vec{3, Float64}\n        u   :: Vec{3, Float64}\n        f   :: Vec{3, Float64}\n    end\n    ParticleProp = @NamedTuple begin\n        x   :: Vec{3, Float64}\n        m   :: Float64\n        V⁰  :: Float64\n        v   :: Vec{3, Float64}\n        a   :: Vec{3, Float64}\n        b   :: Vec{3, Float64}\n        ∇u  :: SecondOrderTensor{3, Float64, 9}\n        F   :: SecondOrderTensor{3, Float64, 9}\n        τ   :: SymmetricSecondOrderTensor{3, Float64, 6}\n        c   :: Tensor{Tuple{@Symmetry{3,3}, 3,3}, Float64, 4, 54}\n    end\n\n    # Background grid\n    grid = generate_grid(GridProp, CartesianMesh(h, (0.0,1.2), (0.0,2.0), (-0.2,0.2)))\n\n    # Particles\n    beam = Sequoia.Box((0,1), (0.85,1.15), (-0.15,0.15))\n    particles = generate_particles(ParticleProp, grid.X; domain=beam)\n    particles.V⁰ .= volume(beam) / length(particles)\n    @. particles.m = ρ⁰ * particles.V⁰\n    @. particles.F = one(particles.F)\n    @. particles.b = Vec(0,-g,0)\n    @show length(particles)\n\n    # Interpolation\n    # Use the kernel correction to properly handle the boundary conditions\n    it = KernelCorrection(QuadraticBSpline())\n    mpvalues = generate_mpvalues(Vec{3}, it, length(particles))\n\n    # Neo-Hookean model\n    function kirchhoff_stress(F)\n        J = det(F)\n        b = symmetric(F ⋅ F')\n        μ*(b-I) + λ*log(J)*I\n    end\n\n    # Sparse matrix\n    A = create_sparse_matrix(Vec{3}, it, grid.X)\n\n    # Outputs\n    outdir = mkpath(joinpath(\"output\", \"implicit_jacobian_based\"))\n    pvdfile = joinpath(outdir, \"paraview\")\n    closepvd(openpvd(pvdfile)) # Create file\n\n    t = 0.0\n    step = 0\n\n    Sequoia.@showprogress while t < T\n\n        for p in eachindex(particles, mpvalues)\n            update!(mpvalues[p], particles.x[p], grid.X)\n        end\n\n        @P2G grid=>i particles=>p mpvalues=>ip begin\n            m[i]  = @∑ N[ip] * m[p]\n            mv[i] = @∑ N[ip] * m[p] * v[p]\n            ma[i] = @∑ N[ip] * m[p] * a[p]\n        end\n\n        # Compute the grid velocity and acceleration at t = tⁿ\n        @. grid.m⁻¹ = inv(grid.m) * !iszero(grid.m)\n        @. grid.vⁿ = grid.mv * grid.m⁻¹\n        @. grid.aⁿ = grid.ma * grid.m⁻¹\n\n        # Update a dof map\n        dofmask = trues(3, size(grid)...)\n        for i in eachindex(grid)\n            dofmask[:,i] .= !iszero(grid.m[i])\n        end\n        for i in eachindex(grid)[1,:,:]\n            dofmask[:,i] .= false\n            grid.vⁿ[i] = zero(Vec{3})\n            grid.aⁿ[i] = zero(Vec{3})\n        end\n        dofmap = DofMap(dofmask)\n\n        # Solve the nonlinear equation\n        state = (; grid, particles, mpvalues, kirchhoff_stress, β, γ, A, dofmap, Δt)\n        @. grid.u = zero(grid.u) # Set zero dispacement for the first guess of the solution\n        U = copy(dofmap(grid.u)) # Convert grid data to plain vector data\n        compute_residual(U) = residual(U, state)\n        compute_jacobian(U) = jacobian(U, state)\n        Sequoia.newton!(U, compute_residual, compute_jacobian)\n\n        # Grid dispacement, velocity and acceleration have been updated during Newton's iterations\n        @G2P grid=>i particles=>p mpvalues=>ip begin\n            ∇u[p] = @∑ u[i] ⊗ ∇N[ip]\n            a[p]  = @∑ a[i] * N[ip]\n            v[p] += @∑ (v[i] - vⁿ[i]) * N[ip]\n            x[p]  = @∑ (X[i] + u[i]) * N[ip]\n            F[p]  = (I + ∇u[p]) ⋅ F[p]\n        end\n\n        t += Δt\n        step += 1\n\n        openpvd(pvdfile; append=true) do pvd\n            openvtk(string(pvdfile, step), particles.x) do vtk\n                vtk[\"velocity\"] = particles.v\n                vtk[\"von Mises\"] = @. vonmises(particles.τ / det(particles.F))\n                pvd[t] = vtk\n            end\n        end\n    end\nend\n\nfunction residual(U::AbstractVector, state)\n    (; grid, particles, mpvalues, kirchhoff_stress, β, γ, dofmap, Δt) = state\n\n    dofmap(grid.u) .= U\n    @. grid.a = (1/(β*Δt^2))*grid.u - (1/(β*Δt))*grid.vⁿ - (1/2β-1)*grid.aⁿ\n    @. grid.v = grid.vⁿ + Δt*((1-γ)*grid.aⁿ + γ*grid.a)\n\n    @G2P grid=>i particles=>p mpvalues=>ip begin\n        # In addition to updating the stress tensor, the stiffness tensor,\n        # which is utilized in the Jacobian-vector product, is also updated.\n        ∇u[p] = @∑ u[i] ⊗ ∇N[ip]\n        c[p], τ[p] = gradient(∇u -> kirchhoff_stress((I + ∇u) ⋅ F[p]), ∇u[p], :all)\n    end\n    @P2G grid=>i particles=>p mpvalues=>ip begin\n        f[i] = @∑ -V⁰[p] * τ[p] ⋅ ∇N[ip] + m[p] * b[p] * N[ip]\n    end\n\n    @. $dofmap(grid.m) * $dofmap(grid.a) - $dofmap(grid.f)\nend\n\nfunction jacobian(U::AbstractVector, state)\n    (; grid, particles, mpvalues, β, A, dofmap, Δt) = state\n\n    I(i,j) = ifelse(i===j, one(Mat{3,3}), zero(Mat{3,3}))\n    @P2G_Matrix grid=>(i,j) particles=>p mpvalues=>(ip,jp) begin\n        A[i,j] = @∑ (∇N[ip] ⋅ c[p] ⋅ ∇N[jp]) * V⁰[p] + 1/(β*Δt^2) * I(i,j) * m[p] * N[jp]\n    end\n\n    submatrix(A, dofmap)\nend","category":"page"},{"location":"examples/implicit_jacobian_based/","page":"Jacobian-based implicit method","title":"Jacobian-based implicit method","text":"","category":"page"},{"location":"examples/implicit_jacobian_based/","page":"Jacobian-based implicit method","title":"Jacobian-based implicit method","text":"This page was generated using Literate.jl.","category":"page"},{"location":"getting_started/#Getting-Started","page":"Getting Started","title":"Getting Started","text":"","category":"section"},{"location":"getting_started/","page":"Getting Started","title":"Getting Started","text":"using Sequoia\nimport Plots\n\n# Material constants\nE = 500                    # Young's modulus\nν = 0.3                    # Poisson's ratio\nλ = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter\nμ = E / 2(1 + ν)           # Shear modulus\nρ = 1000                   # Density\nr = 0.2                    # Radius of disk\n\n# Properties for grid and particles\nstruct GridProp\n    x  :: Vec{2, Float64}\n    m  :: Float64\n    mv :: Vec{2, Float64}\n    f  :: Vec{2, Float64}\n    v  :: Vec{2, Float64}\n    vⁿ :: Vec{2, Float64}\nend\nstruct ParticleProp\n    x  :: Vec{2, Float64}\n    m  :: Float64\n    V  :: Float64\n    v  :: Vec{2, Float64}\n    ∇v :: SecondOrderTensor{2, Float64, 4}\n    σ  :: SymmetricSecondOrderTensor{2, Float64, 3}\nend\n\n# Mesh\nmesh = CartesianMesh(0.05, (0,1), (0,1))\n\n# Background grid\ngrid = generate_grid(GridProp, mesh)\n\n# Particles\nparticles = let\n    pts = generate_particles(ParticleProp, mesh; alg=GridSampling())\n    pts.V .= volume(mesh) / length(pts)\n\n    # Left disk\n    lhs = findall(pts.x) do (x,y)\n        (x-r)^2 + (y-r)^2 < r^2\n    end\n\n    # Right disk\n    s = 1-r\n    rhs = findall(pts.x) do (x,y)\n        (x-s)^2 + (y-s)^2 < r^2\n    end\n\n    pts.v[lhs] .= Vec( 0.1, 0.1)\n    pts.v[rhs] .= Vec(-0.1,-0.1)\n    \n    pts[[lhs; rhs]]\nend\n@. particles.m = ρ * particles.V\n\n# Interpolation\nmpvalues = [MPValue(Vec{2}, LinearBSpline()) for _ in 1:length(particles)]\n\n# Plot results by `Plots.@gif`\nΔt = 0.001\nPlots.@gif for t in range(0, 4-Δt, step=Δt)\n\n    # Update interpolation values\n    for p in 1:length(particles)\n        update!(mpvalues[p], particles[p], mesh)\n    end\n\n    @P2G grid=>i particles=>p mpvalues=>ip begin\n        m[i]  = @∑ N[ip] * m[p]\n        mv[i] = @∑ N[ip] * m[p] * v[p]\n        f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n        vⁿ[i] = mv[i] / m[i]\n        v[i]  = vⁿ[i] + Δt * (f[i]/m[i])\n    end\n\n    @G2P grid=>i particles=>p mpvalues=>ip begin\n        v[p] += @∑ (v[i] - vⁿ[i]) * N[ip]\n        ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n        x[p] += @∑ Δt * v[i] * N[ip]\n    end\n\n    for p in 1:length(particles)\n        Δϵₚ = Δt * symmetric(particles.∇v[p])\n        Δσₚ = λ*tr(Δϵₚ)*I + 2μ*Δϵₚ\n        particles.V[p] *= 1 + tr(Δϵₚ)\n        particles.σ[p] += Δσₚ\n    end\n\n    # plot results\n    Plots.scatter(\n        reinterpret(Tuple{Float64,Float64}, particles.x),\n        lims = (0,1),\n        ticks = 0:0.2:1,\n        minorgrid = true,\n        minorticks = 4,\n        aspect_ratio = :equal,\n        legend = false,\n    )\nend every 100","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"EditURL = \"../../literate/examples/elastic_impact.jl\"","category":"page"},{"location":"examples/elastic_impact/#Transfer-schemes","page":"Transfer schemes","title":"Transfer schemes","text":"","category":"section"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"<video autoplay muted loop playsinline controls width=\"500\" src=\"https://github.com/KeitaNakamura/Sequoia.jl/assets/16015926/adeb872b-036f-4ba8-8915-0b9c6cf331fc\"/></video>","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"In this example, the following transfer schemes are demonstrated:","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"PIC–FLIP mixed transfer[1]\nAffine PIC (APIC) transfer[2]\nTaylor PIC (TPIC) transfer[3]","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"The problem evolves the elastic impact between two rings, which is consistent with previous studies[4][5].","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[1]: Zhu, Y. and Bridson, R., 2005. Animating sand as a fluid. ACM Transactions on Graphics (TOG), 24(3), pp.965-972.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[2]: Jiang, C., Schroeder, C., Selle, A., Teran, J. and Stomakhin, A., 2015. The affine particle-in-cell method. ACM Transactions on Graphics (TOG), 34(4), pp.1-10.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[3]: Nakamura, K., Matsumura, S. and Mizutani, T., 2023. Taylor particle-in-cell transfer and kernel correction for material point method. Computer Methods in Applied Mechanics and Engineering, 403, p.115720.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[4]: de Vaucorbeil, A. and Nguyen, V.P., 2020. A numerical evaluation of the material point method for slid mechanics problems.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"[5]: Huang, P., Zhang, X., Ma, S. and Huang, X., 2011. Contact algorithms for the material point method in impact and penetration simulation. International journal for numerical methods in engineering, 85(4), pp.498-517.","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"using Sequoia\n\nabstract type Transfer end\nstruct FLIP <: Transfer α::Float64 end\nstruct APIC <: Transfer end\nstruct TPIC <: Transfer end\n\nfunction elastic_impact(transfer::Transfer = FLIP(1.0))\n\n    # Simulation parameters\n    h   = 1.0e-3 # Grid spacing\n    T   = 4e-3   # Time span\n    CFL = 0.8    # Courant number\n\n    # Material constants\n    K  = 121.7e6 # Bulk modulus\n    μ  = 26.1e6  # Shear modulus\n    λ  = K-2μ/3  # Lame's first parameter\n    ρ⁰ = 1.01e3  # Initial density\n\n    # Geometry\n    L  = 0.2  # Length of domain\n    W  = 0.15 # Width of domain\n    rᵢ = 0.03 # Inner radius of rings\n    rₒ = 0.04 # Outer radius of rings\n\n    GridProp = @NamedTuple begin\n        x   :: Vec{2, Float64}\n        m   :: Float64\n        m⁻¹ :: Float64\n        mv  :: Vec{2, Float64}\n        f   :: Vec{2, Float64}\n        v   :: Vec{2, Float64}\n        vⁿ  :: Vec{2, Float64}\n    end\n    ParticleProp = @NamedTuple begin\n        x  :: Vec{2, Float64}\n        m  :: Float64\n        V⁰ :: Float64\n        V  :: Float64\n        v  :: Vec{2, Float64}\n        ∇v :: SecondOrderTensor{2, Float64, 4}\n        σ  :: SymmetricSecondOrderTensor{2, Float64, 3}\n        F  :: SecondOrderTensor{2, Float64, 4}\n        B  :: SecondOrderTensor{2, Float64, 4} # for APIC\n    end\n\n    # Background grid\n    grid = generate_grid(GridProp, CartesianMesh(h, (-L/2,L/2), (-W/2,W/2)))\n\n    # Particles\n    particles = let\n        pts = generate_particles(ParticleProp, grid.x)\n        pts.V .= pts.V⁰ .= volume(grid.x) / length(pts)\n\n        lhs = findall(pts.x) do (x, y)\n            rᵢ^2 < (x+L/4)^2+y^2 < rₒ^2\n        end\n        rhs = findall(pts.x) do (x, y)\n            rᵢ^2 < (x-L/4)^2+y^2 < rₒ^2\n        end\n\n        # Set initial velocities\n        @. pts.v[lhs] =  Vec(30, 0)\n        @. pts.v[rhs] = -Vec(30, 0)\n\n        pts[[lhs; rhs]]\n    end\n    @. particles.m = ρ⁰ * particles.V⁰\n    @. particles.F = one(particles.F)\n    @show length(particles)\n\n    # Interpolation\n    mpvalues = generate_mpvalues(Vec{2, Float64}, QuadraticBSpline(), length(particles))\n\n    # Material model (neo-Hookean)\n    function caucy_stress(F)\n        b = F ⋅ F'\n        J = det(F)\n        (μ*(b-I) + λ*log(J)*I) / J\n    end\n\n    # Outputs\n    outdir = mkpath(joinpath(\"output\", \"elastic_impact\"))\n    pvdfile = joinpath(outdir, \"paraview\")\n    closepvd(openpvd(pvdfile)) # create file\n\n    t = 0.0\n    step = 0\n    fps = 12e3\n    savepoints = collect(LinRange(t, T, round(Int, T*fps)+1))\n\n    Sequoia.@showprogress while t < T\n\n        # Calculate timestep based on the wave speed\n        vmax = maximum(@. sqrt((λ+2μ) / (particles.m/particles.V)) + norm(particles.v))\n        Δt = CFL * spacing(grid) / vmax\n\n        # Update interpolation values\n        for p in eachindex(particles, mpvalues)\n            update!(mpvalues[p], particles.x[p], grid.x)\n        end\n\n        # Particle-to-grid transfer\n        if transfer isa FLIP\n            @P2G grid=>i particles=>p mpvalues=>ip begin\n                m[i]  = @∑ N[ip] * m[p]\n                mv[i] = @∑ N[ip] * m[p] * v[p]\n                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n            end\n        elseif transfer isa APIC\n            local Dₚ⁻¹ = inv(1/4 * h^2 * I)\n            @P2G grid=>i particles=>p mpvalues=>ip begin\n                m[i]  = @∑ N[ip] * m[p]\n                mv[i] = @∑ N[ip] * m[p] * (v[p] + B[p] ⋅ Dₚ⁻¹ ⋅ (x[i] - x[p]))\n                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n            end\n        elseif transfer isa TPIC\n            @P2G grid=>i particles=>p mpvalues=>ip begin\n                m[i]  = @∑ N[ip] * m[p]\n                mv[i] = @∑ N[ip] * m[p] * (v[p] + ∇v[p] ⋅ (x[i] - x[p]))\n                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇N[ip]\n            end\n        end\n\n        # Update grid velocity\n        @. grid.m⁻¹ = inv(grid.m) * !iszero(grid.m)\n        @. grid.vⁿ = grid.mv * grid.m⁻¹\n        @. grid.v  = grid.vⁿ + Δt * grid.f * grid.m⁻¹\n\n        # Grid-to-particle transfer\n        if transfer isa FLIP\n            local α = transfer.α\n            @G2P grid=>i particles=>p mpvalues=>ip begin\n                v[p]  = @∑ ((1-α)*v[i] + α*(v[p] + (v[i]-vⁿ[i]))) * N[ip]\n                ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n                x[p] += @∑ Δt * v[i] * N[ip]\n\n            end\n        elseif transfer isa APIC\n            @G2P grid=>i particles=>p mpvalues=>ip begin\n                v[p]  = @∑ v[i] * N[ip]\n                ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n                B[p]  = @∑ v[i] ⊗ (x[i]-x[p]) * N[ip]\n                x[p] += Δt * v[p]\n            end\n        elseif transfer isa TPIC\n            @G2P grid=>i particles=>p mpvalues=>ip begin\n                v[p]  = @∑ v[i] * N[ip]\n                ∇v[p] = @∑ v[i] ⊗ ∇N[ip]\n                x[p] += Δt * v[p]\n            end\n        end\n\n        # Update other particle properties\n        for p in eachindex(particles)\n            ∇uₚ = Δt * particles.∇v[p]\n            Fₚ = (I + ∇uₚ) ⋅ particles.F[p]\n            σₚ = caucy_stress(Fₚ)\n            particles.σ[p] = σₚ\n            particles.F[p] = Fₚ\n            particles.V[p] = det(Fₚ) * particles.V⁰[p]\n        end\n\n        t += Δt\n        step += 1\n\n        if t > first(savepoints)\n            popfirst!(savepoints)\n            openpvd(pvdfile; append=true) do pvd\n                openvtm(string(pvdfile, step)) do vtm\n                    function stress3x3(F)\n                        z = zero(Mat{2,1})\n                        F3x3 = [F  z\n                                z' 1]\n                        caucy_stress(F3x3)\n                    end\n                    openvtk(vtm, particles.x) do vtk\n                        vtk[\"velocity\"] = particles.v\n                        vtk[\"von Mises\"] = @. vonmises(stress3x3(particles.F))\n                    end\n                    openvtk(vtm, grid.x) do vtk\n                        vtk[\"velocity\"] = grid.v\n                    end\n                    pvd[t] = vtm\n                end\n            end\n        end\n    end\nend","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"","category":"page"},{"location":"examples/elastic_impact/","page":"Transfer schemes","title":"Transfer schemes","text":"This page was generated using Literate.jl.","category":"page"},{"location":"#Sequoia","page":"Home","title":"Sequoia","text":"","category":"section"},{"location":"examples/implicit_jacobian_free/","page":"Jacobian-free Newton–Krylov method","title":"Jacobian-free Newton–Krylov method","text":"EditURL = \"../../literate/examples/implicit_jacobian_free.jl\"","category":"page"},{"location":"examples/implicit_jacobian_free/#Jacobian-free-Newton–Krylov-method","page":"Jacobian-free Newton–Krylov method","title":"Jacobian-free Newton–Krylov method","text":"","category":"section"},{"location":"examples/implicit_jacobian_free/","page":"Jacobian-free Newton–Krylov method","title":"Jacobian-free Newton–Krylov method","text":"using Sequoia\n\nusing IterativeSolvers: gmres!\nusing LinearMaps: LinearMap\n\nfunction implicit_jacobian_free()\n\n    # Simulation parameters\n    h  = 0.05 # Grid spacing\n    T  = 1.0  # Time span\n    g  = 20.0 # Gravity acceleration\n    Δt = 0.02 # Timestep\n\n    # Material constants\n    E  = 1e6                    # Young's modulus\n    ν  = 0.3                    # Poisson's ratio\n    λ  = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter\n    μ  = E / 2(1 + ν)           # Shear modulus\n    ρ⁰ = 500.0                  # Density\n\n    # Newmark-beta integration\n    β = 1/4\n    γ = 1/2\n\n    GridProp = @NamedTuple begin\n        X   :: Vec{3, Float64}\n        m   :: Float64\n        m⁻¹ :: Float64\n        v   :: Vec{3, Float64}\n        vⁿ  :: Vec{3, Float64}\n        mv  :: Vec{3, Float64}\n        a   :: Vec{3, Float64}\n        aⁿ  :: Vec{3, Float64}\n        ma  :: Vec{3, Float64}\n        u   :: Vec{3, Float64}\n        f   :: Vec{3, Float64}\n    end\n    ParticleProp = @NamedTuple begin\n        x   :: Vec{3, Float64}\n        m   :: Float64\n        V⁰  :: Float64\n        v   :: Vec{3, Float64}\n        a   :: Vec{3, Float64}\n        b   :: Vec{3, Float64}\n        ∇u  :: SecondOrderTensor{3, Float64, 9}\n        F   :: SecondOrderTensor{3, Float64, 9}\n        τ   :: SymmetricSecondOrderTensor{3, Float64, 6}\n        c   :: Tensor{Tuple{@Symmetry{3,3}, 3,3}, Float64, 4, 54}\n    end\n\n    # Background grid\n    grid = generate_grid(GridProp, CartesianMesh(h, (0.0,1.2), (0.0,2.0), (-0.2,0.2)))\n\n    # Particles\n    beam = Sequoia.Box((0,1), (0.85,1.15), (-0.15,0.15))\n    particles = generate_particles(ParticleProp, grid.X; domain=beam)\n    particles.V⁰ .= volume(beam) / length(particles)\n    @. particles.m = ρ⁰ * particles.V⁰\n    @. particles.F = one(particles.F)\n    @. particles.b = Vec(0,-g,0)\n    @show length(particles)\n\n    # Interpolation\n    # Use the kernel correction to properly handle the boundary conditions\n    mpvalues = generate_mpvalues(Vec{3}, KernelCorrection(QuadraticBSpline()), length(particles))\n\n    # Neo-Hookean model\n    function kirchhoff_stress(F)\n        J = det(F)\n        b = symmetric(F ⋅ F')\n        μ*(b-I) + λ*log(J)*I\n    end\n\n    # Outputs\n    outdir = mkpath(joinpath(\"output\", \"implicit_jacobian_free\"))\n    pvdfile = joinpath(outdir, \"paraview\")\n    closepvd(openpvd(pvdfile)) # Create file\n\n    t = 0.0\n    step = 0\n\n    Sequoia.@showprogress while t < T\n\n        for p in eachindex(particles, mpvalues)\n            update!(mpvalues[p], particles.x[p], grid.X)\n        end\n\n        @P2G grid=>i particles=>p mpvalues=>ip begin\n            m[i]  = @∑ N[ip] * m[p]\n            mv[i] = @∑ N[ip] * m[p] * v[p]\n            ma[i] = @∑ N[ip] * m[p] * a[p]\n        end\n\n        # Compute the grid velocity and acceleration at t = tⁿ\n        @. grid.m⁻¹ = inv(grid.m) * !iszero(grid.m)\n        @. grid.vⁿ = grid.mv * grid.m⁻¹\n        @. grid.aⁿ = grid.ma * grid.m⁻¹\n\n        # Update a dof map\n        dofmask = trues(3, size(grid)...)\n        for i in eachindex(grid)\n            dofmask[:,i] .= !iszero(grid.m[i])\n        end\n        for i in eachindex(grid)[1,:,:]\n            dofmask[:,i] .= false\n            grid.vⁿ[i] = zero(Vec{3})\n            grid.aⁿ[i] = zero(Vec{3})\n        end\n        dofmap = DofMap(dofmask)\n\n        # Solve the nonlinear equation\n        state = (; grid, particles, mpvalues, kirchhoff_stress, β, γ, dofmap, Δt)\n        @. grid.u = zero(grid.u) # Set zero dispacement for the first guess of the solution\n        U = copy(dofmap(grid.u)) # Convert grid data to plain vector data\n        compute_residual(U) = residual(U, state)\n        compute_jacobian(U) = jacobian(U, state)\n        Sequoia.newton!(U, compute_residual, compute_jacobian; linsolve = (x,A,b)->gmres!(x,A,b))\n\n        # Grid dispacement, velocity and acceleration have been updated during Newton's iterations\n        @G2P grid=>i particles=>p mpvalues=>ip begin\n            ∇u[p] = @∑ u[i] ⊗ ∇N[ip]\n            a[p]  = @∑ a[i] * N[ip]\n            v[p] += @∑ (v[i] - vⁿ[i]) * N[ip]\n            x[p]  = @∑ (X[i] + u[i]) * N[ip]\n            F[p]  = (I + ∇u[p]) ⋅ F[p]\n        end\n\n        t += Δt\n        step += 1\n\n        openpvd(pvdfile; append=true) do pvd\n            openvtk(string(pvdfile, step), particles.x) do vtk\n                vtk[\"velocity\"] = particles.v\n                vtk[\"von Mises\"] = @. vonmises(particles.τ / det(particles.F))\n                pvd[t] = vtk\n            end\n        end\n    end\nend\n\nfunction residual(U::AbstractVector, state)\n    (; grid, particles, mpvalues, kirchhoff_stress, β, γ, dofmap, Δt) = state\n\n    dofmap(grid.u) .= U\n    @. grid.a = (1/(β*Δt^2))*grid.u - (1/(β*Δt))*grid.vⁿ - (1/2β-1)*grid.aⁿ\n    @. grid.v = grid.vⁿ + Δt*((1-γ)*grid.aⁿ + γ*grid.a)\n\n    @G2P grid=>i particles=>p mpvalues=>ip begin\n        # In addition to updating the stress tensor, the stiffness tensor,\n        # which is utilized in the Jacobian-vector product, is also updated.\n        ∇u[p] = @∑ u[i] ⊗ ∇N[ip]\n        c[p], τ[p] = gradient(∇u -> kirchhoff_stress((I + ∇u) ⋅ F[p]), ∇u[p], :all)\n    end\n    @P2G grid=>i particles=>p mpvalues=>ip begin\n        f[i] = @∑ -V⁰[p] * τ[p] ⋅ ∇N[ip] + m[p] * b[p] * N[ip]\n    end\n\n    @. β*Δt^2 * ($dofmap(grid.a) - $dofmap(grid.f) * $dofmap(grid.m⁻¹))\nend\n\nfunction jacobian(U::AbstractVector, state)\n    (; grid, particles, mpvalues, β, dofmap, Δt) = state\n\n    # Create a linear map to represent Jacobian-vector product J*δU.\n    # `U` is acutally not used because the stiffness tensor is already calculated\n    # when computing the residual vector.\n    LinearMap(ndofs(dofmap)) do JδU, δU\n        dofmap(grid.u) .= δU\n\n        @G2P grid=>i particles=>p mpvalues=>ip begin\n            ∇u[p] = @∑ u[i] ⊗ ∇N[ip]\n            τ[p] = c[p] ⊡ ∇u[p]\n        end\n        @P2G grid=>i particles=>p mpvalues=>ip begin\n            f[i] = @∑ -V⁰[p] * τ[p] ⋅ ∇N[ip]\n        end\n\n        @. JδU = δU - β*Δt^2 * $dofmap(grid.f) * $dofmap(grid.m⁻¹)\n    end\nend","category":"page"},{"location":"examples/implicit_jacobian_free/","page":"Jacobian-free Newton–Krylov method","title":"Jacobian-free Newton–Krylov method","text":"","category":"page"},{"location":"examples/implicit_jacobian_free/","page":"Jacobian-free Newton–Krylov method","title":"Jacobian-free Newton–Krylov method","text":"This page was generated using Literate.jl.","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"EditURL = \"../../literate/examples/tlmpm_vortex.jl\"","category":"page"},{"location":"examples/tlmpm_vortex/#Total-Lagrangian-MPM","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"","category":"section"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"<video autoplay muted loop playsinline controls width=\"300\" src=\"https://github.com/KeitaNakamura/Sequoia.jl/assets/16015926/81d2c7a1-d0fc-4122-bd3c-0bc8f73ca3fa\"/></video>","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"This example demonstrates the total lagrangian material point method[1]. The implementation solves generalized vortex problem[1] using a linear kernel.","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"note: Note\nCurrently, the Bernstein function used in the paper[1] has not been implemented.","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"[1]: de Vaucorbeil, A., Nguyen, V.P. and Hutchinson, C.R., 2020. A Total-Lagrangian Material Point Method for solid mechanics problems involving large deformations. Computer Methods in Applied Mechanics and Engineering, 360, p.112783.","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"using Sequoia\n\nfunction tlmpm_vortex()\n\n    # Simulation parameters\n    h   = 0.02 # Grid spacing\n    T   = 1.0  # Time span\n    CFL = 0.1  # Courant number\n    α   = 0.99 # PIC-FLIP parameter\n\n    # Material constants\n    E  = 1e6                    # Young's modulus\n    ν  = 0.3                    # Poisson's ratio\n    λ  = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter\n    μ  = E / 2(1 + ν)           # Shear modulus\n    ρ⁰ = 1e3                    # Initial density\n\n    # Geometry\n    Rᵢ = 0.75\n    Rₒ = 1.25\n\n    # Equations for vortex\n    G = π\n    R̄ = (Rᵢ + Rₒ) / 2\n    function calc_b_Rθ(R, t)\n        local h′′, h′, h = hessian(R -> 1-8((R-R̄)/(Rᵢ-Rₒ))^2+16((R-R̄)/(Rᵢ-Rₒ))^4, R, :all)\n        local g′′, g′, g = hessian(t -> G*sin(π*t/T), t, :all)\n        β = g * h\n        b_R = ( μ/ρ⁰*(3g*h′+R*g*h′′) - R*g′′*h)*sin(β) + (μ/ρ⁰*R*(g*h′)^2 - R*(g′*h)^2)*cos(β)\n        b_θ = (-μ/ρ⁰*(3g*h′+R*g*h′′) + R*g′′*h)*cos(β) + (μ/ρ⁰*R*(g*h′)^2 + R*(g′*h)^2)*sin(β)\n        Vec(b_R, b_θ)\n    end\n    isinside(x::Vec) = Rᵢ^2 < x⋅x < Rₒ^2\n\n    GridProp = @NamedTuple begin\n        X    :: Vec{2, Float64}\n        m    :: Float64\n        m⁻¹  :: Float64\n        mv   :: Vec{2, Float64}\n        fint :: Vec{2, Float64}\n        fext :: Vec{2, Float64}\n        b    :: Vec{2, Float64}\n        v    :: Vec{2, Float64}\n        vⁿ   :: Vec{2, Float64}\n    end\n    ParticleProp = @NamedTuple begin\n        x  :: Vec{2, Float64}\n        X  :: Vec{2, Float64}\n        m  :: Float64\n        V⁰ :: Float64\n        v  :: Vec{2, Float64}\n        ṽ  :: Vec{2, Float64}\n        ã  :: Vec{2, Float64}\n        P  :: SecondOrderTensor{2, Float64, 4}\n        F  :: SecondOrderTensor{2, Float64, 4}\n    end\n\n    # Background grid\n    grid = generate_grid(GridProp, CartesianMesh(h, (-1.5,1.5), (-1.5,1.5)))\n    outside_gridinds = findall(!isinside, grid.X)\n\n    # Particles\n    particles = generate_particles(ParticleProp, grid.X; alg=GridSampling(), spacing=1)\n    particles.V⁰ .= volume(grid.X) / length(particles)\n\n    filter!(pt->isinside(pt.x), particles)\n\n    @. particles.X = particles.x\n    @. particles.m = ρ⁰ * particles.V⁰\n    @. particles.F = one(particles.F)\n    @show length(particles)\n\n    # Precompute linear kernel values\n    mpvalues = generate_mpvalues(Vec{2, Float64}, LinearBSpline(), length(particles))\n    for p in eachindex(particles, mpvalues)\n        update!(mpvalues[p], particles.x[p], grid.X)\n    end\n\n    # Outputs\n    outdir = mkpath(joinpath(\"output\", \"tlmpm_vortex\"))\n    pvdfile = joinpath(outdir, \"paraview\")\n    closepvd(openpvd(pvdfile)) # create file\n\n    t = 0.0\n    step = 0\n    fps = 60\n    savepoints = collect(LinRange(t, T, round(Int, T*fps)+1))\n\n    Sequoia.@showprogress while t < T\n\n        # Calculate timestep based on the wave speed\n        vmax = maximum(@. sqrt((λ+2μ) / (particles.m/(particles.V⁰ * det(particles.F)))) +\n                          norm(particles.v))\n        Δt = CFL * spacing(grid) / vmax\n\n        # Compute grid body forces\n        for i in eachindex(grid)\n            if isinside(grid.X[i])\n                (x, y) = grid.X[i]\n                R = sqrt(x^2 + y^2)\n                θ = atan(y, x)\n                grid.b[i] = rotmat(θ) ⋅ calc_b_Rθ(R, t)\n            end\n        end\n\n        # Particle-to-grid transfer\n        @P2G grid=>i particles=>p mpvalues=>ip begin\n            m[i]    = @∑ N[ip] * m[p]\n            mv[i]   = @∑ N[ip] * m[p] * v[p]\n            fint[i] = @∑ -V⁰[p] * P[p] ⋅ ∇N[ip]\n        end\n\n        # Update grid velocity\n        @. grid.m⁻¹  = inv(grid.m) * !iszero(grid.m)\n        @. grid.fext = grid.m * grid.b\n        @. grid.vⁿ   = grid.mv * grid.m⁻¹\n        @. grid.v    = grid.vⁿ + Δt * (grid.fint + grid.fext) * grid.m⁻¹\n        grid.v[outside_gridinds] .= zero(eltype(grid.v))\n\n        # Update particle velocity and position\n        @G2P grid=>i particles=>p mpvalues=>ip begin\n            ṽ[p]  = @∑ v[i] * N[ip]\n            ã[p]  = @∑ (v[i] - vⁿ[i])/Δt * N[ip]\n            v[p]  = (1-α)*ṽ[p] + α*(v[p] + Δt*ã[p])\n            x[p] += Δt * ṽ[p]\n        end\n\n        # Remap updated velocity to grid (MUSL)\n        @P2G grid=>i particles=>p mpvalues=>ip begin\n            mv[i] = @∑ N[ip] * m[p] * v[p]\n            v[i]  = mv[i] * m⁻¹[i]\n        end\n        grid.v[outside_gridinds] .= zero(eltype(grid.v))\n\n        # Update stress\n        @G2P grid=>i particles=>p mpvalues=>ip begin\n            F[p] += @∑ Δt * v[i] ⊗ ∇N[ip]\n            P[p]  = μ * (F[p] - inv(F[p])') + λ * log(det(F[p])) * inv(F[p])'\n        end\n\n        t += Δt\n        step += 1\n\n        if t > first(savepoints)\n            popfirst!(savepoints)\n            openpvd(pvdfile; append=true) do pvd\n                openvtm(string(pvdfile, step)) do vtm\n                    angle(x) = atan(x[2], x[1])\n                    openvtk(vtm, particles.x) do vtk\n                        vtk[\"velocity\"] = particles.v\n                        vtk[\"initial angle\"] = angle.(particles.X)\n                    end\n                    openvtk(vtm, grid.X) do vtk\n                        vtk[\"external force\"] = grid.fext\n                    end\n                    pvd[t] = vtm\n                end\n            end\n        end\n    end\nend","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"","category":"page"},{"location":"examples/tlmpm_vortex/","page":"Total Lagrangian MPM","title":"Total Lagrangian MPM","text":"This page was generated using Literate.jl.","category":"page"}]
}