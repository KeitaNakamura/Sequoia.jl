# # Hyperelastic material
#
# ```@raw html
# <img class="display-light-only" src="https://user-images.githubusercontent.com/16015926/233059400-2204f758-97f4-442d-b26f-34ad827deddf.mp4" width="400"/>
# <img class="display-dark-only" src="https://user-images.githubusercontent.com/16015926/233059452-acb6a044-2ba6-4bc3-933f-d770cc191689.mp4" width="400"/>
# ```

using Marble
using StableRNGs #src

include(joinpath(pkgdir(Marble), "docs/literate/models/NeoHookean.jl"))

function hyperelastic_material(
        itp::Interpolation = KernelCorrection(QuadraticBSpline()),
        alg::TransferAlgorithm = TPIC(),
        ;output::Bool = true, #src
        test::Bool = false,   #src
    )

    ## simulation parameters
    g      = 9.81 # gravity acceleration
    CFL    = 0.5  # Courant number
    t_stop = 6.0  # time for simulation
    ## use low resolution for testing purpose #src
    if test                                   #src
        Δx::Float64 = 0.25                    #src
    else                                      #src
    Δx     = 0.1 # grid spacing
    end                                       #src

    ## material constants
    ρ₀      = 1.0e3 # initial density
    elastic = NeoHookean(; E=1e6, ν=0.3)

    ## states for grid and particles
    GridState = @NamedTuple begin
        x  :: Vec{3, Float64}
        m  :: Float64
        mv :: Vec{3, Float64}
        f  :: Vec{3, Float64}
        v  :: Vec{3, Float64}
        vⁿ :: Vec{3, Float64}
    end
    ParticleState = @NamedTuple begin
        x  :: Vec{3, Float64}
        m  :: Float64
        V  :: Float64
        V₀ :: Float64
        v  :: Vec{3, Float64}
        ∇v :: SecondOrderTensor{3, Float64, 9}
        σ  :: SymmetricSecondOrderTensor{3, Float64, 6}
        F  :: SecondOrderTensor{3, Float64, 9}
        b  :: Vec{3, Float64}
        l  :: Float64                          # for uGIMP
        B  :: SecondOrderTensor{3, Float64, 9} # for APIC
        C  :: Mat{3, 4, Float64, 12}           # for WLS
    end

    ## grid
    grid = generate_grid(GridState, Δx, (-2,2), (0,30), (-2,2))

    ## particles
    r = 0.2
    if test                                                                                                                    #src
        RNG = StableRNG(1234)                                                                                                  #src
        centroids::Vector{NTuple{3, Float64}} = Marble.poisson_disk_sampling(RNG, 3r, (-0.8,0.8), (6,28), (-0.8,0.8))          #src
        particles::Marble.infer_particles_type(ParticleState) =                                                                #src
            mapreduce(vcat, centroids) do x                                                                                    #src
                if rand(RNG, Bool)                                                                                             #src
                    generate_particles(SphericalDomain(Vec(x), r), ParticleState, grid.x; alg=PoissonDiskSampling(RNG))        #src
                else                                                                                                           #src
                    generate_particles(BoxDomain(tuple.((x.-r), (x.+r))), ParticleState, grid.x; alg=PoissonDiskSampling(RNG)) #src
                end                                                                                                            #src
            end                                                                                                                #src
    else                                                                                                                       #src
    centroids = Marble.poisson_disk_sampling(3r, (-0.8,0.8), (6,28), (-0.8,0.8))
    particles = mapreduce(vcat, centroids) do x
        if rand(Bool)
            generate_particles(SphericalDomain(Vec(x), r), ParticleState, grid.x)
        else
            generate_particles(BoxDomain(tuple.((x.-r), (x.+r))), ParticleState, grid.x)
        end
    end
    end                                                                                                                        #src
    @. particles.V₀ = particles.V
    @. particles.m  = ρ₀ * particles.V
    @. particles.F  = one(particles.F)
    @. particles.b  = Vec(0,-g,0)
    @show length(particles)

    ## create interpolation space
    space = MPSpace(itp, size(grid), length(particles))

    ## outputs
    if output                                                #src
    outdir = joinpath("output.tmp", "hyperelastic_material")
    rm(outdir; recursive=true, force=true)                   #src
    pvdfile = joinpath(mkpath(outdir), "paraview")
    closepvd(openpvd(pvdfile))
    end                                                      #src

    t = 0.0
    step = 0
    fps = 50
    savepoints = collect(LinRange(t, t_stop, round(Int, t_stop*fps)+1))
    while t < t_stop

        ## calculate timestep based on the Courant-Friedrichs-Lewy (CFL) condition
        Δt = CFL * spacing(grid) / maximum(eachparticle(particles)) do pt
            λ, μ = elastic.λ, elastic.μ
            ρ = pt.m / pt.V
            vc = √((λ+2μ) / ρ)
            vc + norm(pt.v)
        end

        ## update interpolation space
        update!(space, grid, particles)

        ## P2G transfer
        particle_to_grid!((:m,:mv,:f), fillzero!(grid), particles, space; alg)

        ## solve momentum equation
        @. grid.vⁿ = grid.mv / grid.m * !iszero(grid.m)
        @. grid.v = grid.vⁿ + Δt*(grid.f/grid.m) * !iszero(grid.m)

        ## boundary conditions
        @inbounds for i in @view eachindex(grid)[:,begin,:] # bottom
            grid.v[i] = grid.v[i] .* (true,false,true)
        end
        @inbounds for i in @view eachindex(grid)[[begin,end],:,:] # left/right
            grid.v[i] = grid.v[i] .* (false,true,true)
        end
        @inbounds for i in @view eachindex(grid)[:,:,[begin,end]] # front/back
            grid.v[i] = grid.v[i] .* (true,true,false)
        end

        ## G2P transfer
        grid_to_particle!((:v,:∇v,:x), particles, grid, space, Δt; alg)

        ## update other particle states
        Marble.@threads_inbounds for pt in eachparticle(particles)
            F = (I + Δt*pt.∇v) ⋅ pt.F
            pt.σ = compute_cauchy_stress(elastic, F)
            pt.F = F
            pt.V = det(F) * pt.V₀
        end

        t += Δt
        step += 1

        if output #src
        if t > first(savepoints)
            popfirst!(savepoints)
            openpvd(pvdfile; append=true) do pvd
                pts = filter(pt->pt.x[2]<6, particles)
                !isempty(pts) && openvtk(string(pvdfile, step), pts.x) do vtk
                    vtk["velocity"] = pts.v
                    pvd[t] = vtk
                end
            end
        end
        end #src
    end
    ifelse(test, particles, nothing) #src
end

## check the result                                                                                                                                                     #src
using Test                                                                                                                                                              #src
if @isdefined(RUN_TESTS) && RUN_TESTS                                                                                                                                   #src
@test mean(hyperelastic_material(KernelCorrection(QuadraticBSpline()), TPIC(); test=true).x) ≈ [0.03340231371487502, 1.8072011731571507, 0.06236152833092378] rtol=1e-5 #src
end                                                                                                                                                                     #src
