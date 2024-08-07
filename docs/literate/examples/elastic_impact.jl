# # Transfer schemes
#
# In this example, the following transfer schemes are demonstrated:
# * PIC--FLIP mixed transfer[^1]
# * Affine PIC (APIC) transfer[^2]
# * Taylor PIC (TPIC) transfer[^3]
#
# The problem evolves the elastic impact between two rings, which is consistent with previous studies[^4].
#
# [^1]: [Zhu, Y. and Bridson, R., 2005. Animating sand as a fluid. ACM Transactions on Graphics (TOG), 24(3), pp.965-972.](https://doi.org/10.1145/1073204.1073298)
# [^2]: [Jiang, C., Schroeder, C., Selle, A., Teran, J. and Stomakhin, A., 2015. The affine particle-in-cell method. ACM Transactions on Graphics (TOG), 34(4), pp.1-10.](https://doi.org/10.1145/2766996)
# [^3]: [Nakamura, K., Matsumura, S. and Mizutani, T., 2023. Taylor particle-in-cell transfer and kernel correction for material point method. Computer Methods in Applied Mechanics and Engineering, 403, p.115720.](https://doi.org/10.1016/j.cma.2022.115720)
# [^4]: [Li, X., Fang, Y., Li, M. and Jiang, C., 2022. BFEMP: Interpenetration-free MPM–FEM coupling with barrier contact. Computer Methods in Applied Mechanics and Engineering, 390, p.114350.](https://doi.org/10.1016/j.cma.2021.114350)
#

using Sequoia

abstract type Transfer end
struct FLIP <: Transfer α::Float64 end
struct APIC <: Transfer end
struct TPIC <: Transfer end

function main(transfer::Transfer = FLIP(1.0))

    ## Simulation parameters
    h   = 0.1 # Grid spacing
    T   = 0.6 # Time span
    CFL = 0.8 # Courant number

    ## Material constants
    E  = 100e6                  # Young's modulus
    ν  = 0.2                    # Poisson's ratio
    λ  = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter
    μ  = E / 2(1 + ν)           # Shear modulus
    ρ⁰ = 1e3                    # Initial density

    ## Geometry
    L  = 20.0 # Length of domain
    W  = 15.0 # Width of domain
    rᵢ = 3.0  # Inner radius of rings
    rₒ = 4.0  # Outer radius of rings

    GridProp = @NamedTuple begin
        x   :: Vec{2, Float64}
        m   :: Float64
        m⁻¹ :: Float64
        mv  :: Vec{2, Float64}
        f   :: Vec{2, Float64}
        v   :: Vec{2, Float64}
        vⁿ  :: Vec{2, Float64}
    end
    ParticleProp = @NamedTuple begin
        x  :: Vec{2, Float64}
        m  :: Float64
        V⁰ :: Float64
        V  :: Float64
        v  :: Vec{2, Float64}
        ∇v :: SecondOrderTensor{2, Float64, 4}
        σ  :: SymmetricSecondOrderTensor{2, Float64, 3}
        F  :: SecondOrderTensor{2, Float64, 4}
        B  :: SecondOrderTensor{2, Float64, 4} # for APIC
    end

    ## Background grid
    grid = generate_grid(GridProp, CartesianMesh(h, (-L,L), (-W/2,W/2)))

    ## Particles
    particles = let
        pts = generate_particles(ParticleProp, grid.x)
        pts.V .= pts.V⁰ .= volume(grid.x) / length(pts)

        lhs = findall(pts.x) do (x, y)
            rᵢ^2 < (x+L/4)^2+y^2 < rₒ^2
        end
        rhs = findall(pts.x) do (x, y)
            rᵢ^2 < (x-L/4)^2+y^2 < rₒ^2
        end

        ## Set initial velocities
        @. pts.v[lhs] =  Vec(30, 0)
        @. pts.v[rhs] = -Vec(30, 0)

        pts[[lhs; rhs]]
    end
    @. particles.m = ρ⁰ * particles.V⁰
    @. particles.F = one(particles.F)
    @show length(particles)

    ## Interpolation
    mpvalues = generate_mpvalues(Vec{2, Float64}, QuadraticBSpline(), length(particles))

    ## Material model (neo-Hookean)
    function caucy_stress(F)
        b = F ⋅ F'
        J = det(F)
        (μ*(b-I) + λ*log(J)*I) / J
    end

    ## Outputs
    outdir = mkpath(joinpath("output", "elastic_impact"))
    pvdfile = joinpath(outdir, "paraview")
    closepvd(openpvd(pvdfile)) # create file

    t = 0.0
    step = 0
    fps = 120
    savepoints = collect(LinRange(t, T, round(Int, T*fps)+1))

    Sequoia.@showprogress while t < T

        ## Calculate timestep based on the wave speed
        vmax = maximum(@. sqrt((λ+2μ) / (particles.m/particles.V)) + norm(particles.v))
        Δt = CFL * spacing(grid) / vmax

        ## Update interpolation values
        for p in eachindex(particles, mpvalues)
            update!(mpvalues[p], particles.x[p], grid.x)
        end

        ## Particle-to-grid transfer
        if transfer isa FLIP
            @P2G grid=>i particles=>p mpvalues=>ip begin
                m[i]  = @∑ w[ip] * m[p]
                mv[i] = @∑ w[ip] * m[p] * v[p]
                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇w[ip]
            end
        elseif transfer isa APIC
            local Dₚ⁻¹ = inv(1/4 * h^2 * I)
            @P2G grid=>i particles=>p mpvalues=>ip begin
                m[i]  = @∑ w[ip] * m[p]
                mv[i] = @∑ w[ip] * m[p] * (v[p] + B[p] ⋅ Dₚ⁻¹ ⋅ (x[i] - x[p]))
                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇w[ip]
            end
        elseif transfer isa TPIC
            @P2G grid=>i particles=>p mpvalues=>ip begin
                m[i]  = @∑ w[ip] * m[p]
                mv[i] = @∑ w[ip] * m[p] * (v[p] + ∇v[p] ⋅ (x[i] - x[p]))
                f[i]  = @∑ -V[p] * σ[p] ⋅ ∇w[ip]
            end
        end

        ## Update grid velocity
        @. grid.m⁻¹ = inv(grid.m) * !iszero(grid.m)
        @. grid.vⁿ = grid.mv * grid.m⁻¹
        @. grid.v  = grid.vⁿ + Δt * grid.f * grid.m⁻¹

        ## Grid-to-particle transfer
        if transfer isa FLIP
            local α = transfer.α
            @G2P grid=>i particles=>p mpvalues=>ip begin
                v[p]  = @∑ w[ip] * ((1-α)*v[i] + α*(v[p] + (v[i]-vⁿ[i])))
                ∇v[p] = @∑ v[i] ⊗ ∇w[ip]
                x[p] += @∑ Δt * (w[ip] * v[i])

            end
        elseif transfer isa APIC
            @G2P grid=>i particles=>p mpvalues=>ip begin
                v[p]  = @∑ w[ip] * v[i]
                ∇v[p] = @∑ v[i] ⊗ ∇w[ip]
                B[p]  = @∑ w[ip] * v[i] ⊗ (x[i]-x[p])
                x[p] += Δt * v[p]
            end
        elseif transfer isa TPIC
            @G2P grid=>i particles=>p mpvalues=>ip begin
                v[p]  = @∑ w[ip] * v[i]
                ∇v[p] = @∑ v[i] ⊗ ∇w[ip]
                x[p] += Δt * v[p]
            end
        end

        ## Update other particle properties
        for p in eachindex(particles)
            ∇uₚ = Δt * particles.∇v[p]
            Fₚ = (I + ∇uₚ) ⋅ particles.F[p]
            σₚ = caucy_stress(Fₚ)
            particles.σ[p] = σₚ
            particles.F[p] = Fₚ
            particles.V[p] = det(Fₚ) * particles.V⁰[p]
        end

        t += Δt
        step += 1

        if t > first(savepoints)
            popfirst!(savepoints)
            openpvd(pvdfile; append=true) do pvd
                openvtm(string(pvdfile, step)) do vtm
                    function stress3x3(F)
                        z = zero(Mat{2,1})
                        F3x3 = [F  z
                                z' 1]
                        caucy_stress(F3x3)
                    end
                    openvtk(vtm, particles.x) do vtk
                        vtk["velocity"] = particles.v
                        vtk["von Mises"] = @. vonmises(stress3x3(particles.F))
                    end
                    openvtk(vtm, grid.x) do vtk
                        vtk["velocity"] = grid.v
                    end
                    pvd[t] = vtm
                end
            end
        end
    end
    norm(mean(particles.x)) #src
end

using Test                            #src
if @isdefined(RUN_TESTS) && RUN_TESTS #src
    @test main(FLIP(0.0))  < 0.1      #src
    @test main(FLIP(1.0))  < 0.1      #src
    @test main(FLIP(0.99)) < 0.1      #src
    @test main(APIC())     < 0.1      #src
    @test main(TPIC())     < 0.1      #src
end                                   #src
