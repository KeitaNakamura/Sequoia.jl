# # Total Lagrangian MPM
#
# ```@raw html
# <video autoplay muted loop playsinline controls width="300" src="https://github.com/KeitaNakamura/Sequoia.jl/assets/16015926/81d2c7a1-d0fc-4122-bd3c-0bc8f73ca3fa"/></video>
# ```
#
# This example demonstrates the total lagrangian material point method[^1].
# The implementation solves generalized vortex problem[^1] using a linear kernel.
#
# !!! note
#     Currently, the Bernstein function used in the paper[^1] has not been implemented.
#
# [^1]: [de Vaucorbeil, A., Nguyen, V.P. and Hutchinson, C.R., 2020. A Total-Lagrangian Material Point Method for solid mechanics problems involving large deformations. Computer Methods in Applied Mechanics and Engineering, 360, p.112783.](https://doi.org/10.1016/j.cma.2019.112783)

using Sequoia

function tlmpm_vortex()

    ## simulation parameters
    CFL    = 0.1  # Courant number
    Δx     = 0.02 # grid spacing
    t_stop = 1.0  # simulation stops at t=t_stop
    α      = 0.99 # PIC-FLIP parameter

    ## material constants
    E  = 1e6                    # Young's modulus
    ν  = 0.3                    # Poisson's ratio
    λ  = (E*ν) / ((1+ν)*(1-2ν)) # Lame's first parameter
    μ  = E / 2(1 + ν)           # shear modulus
    ρ⁰ = 1e3                    # initial density

    ## geometry
    Rᵢ = 0.75
    Rₒ = 1.25

    ## equations for vortex
    G = π
    T = 1.0
    R̄ = (Rᵢ + Rₒ) / 2
    function calc_b_Rθ(R, t)
        h′′, h′, h = hessian(R -> 1-8((R-R̄)/(Rᵢ-Rₒ))^2+16((R-R̄)/(Rᵢ-Rₒ))^4, R, :all)
        g′′, g′, g = hessian(t -> G*sin(π*t/T), t, :all)
        β = g * h
        b_R = ( μ/ρ⁰*(3g*h′+R*g*h′′) - R*g′′*h)*sin(β) + (μ/ρ⁰*R*(g*h′)^2 - R*(g′*h)^2)*cos(β)
        b_θ = (-μ/ρ⁰*(3g*h′+R*g*h′′) + R*g′′*h)*cos(β) + (μ/ρ⁰*R*(g*h′)^2 + R*(g′*h)^2)*sin(β)
        Vec(b_R, b_θ)
    end
    isinside(x::Vec) = Rᵢ^2 < x⋅x < Rₒ^2

    ## properties for grid and particles
    GridProp = @NamedTuple begin
        X    :: Vec{2, Float64}
        m    :: Float64
        m⁻¹  :: Float64
        mv   :: Vec{2, Float64}
        fint :: Vec{2, Float64}
        fext :: Vec{2, Float64}
        b    :: Vec{2, Float64}
        v    :: Vec{2, Float64}
        vⁿ   :: Vec{2, Float64}
    end
    ParticleProp = @NamedTuple begin
        x  :: Vec{2, Float64}
        X  :: Vec{2, Float64}
        m  :: Float64
        V⁰ :: Float64
        v  :: Vec{2, Float64}
        ṽ  :: Vec{2, Float64}
        ã  :: Vec{2, Float64}
        P  :: SecondOrderTensor{2, Float64, 4}
        F  :: SecondOrderTensor{2, Float64, 4}
    end

    ## background grid
    grid = generate_grid(GridProp, CartesianMesh(Δx, (-1.5,1.5), (-1.5,1.5)))
    outside_gridinds = findall(!isinside, grid.X)

    ## particles
    particles = generate_particles(ParticleProp, grid.X; alg=GridSampling(), spacing=1)
    particles.V⁰ .= prod(grid.X[end]-grid.X[1]) / length(particles)

    filter!(pt->isinside(pt.x), particles)

    @. particles.X = particles.x
    @. particles.m = ρ⁰ * particles.V⁰
    @. particles.F = one(particles.F)
    @show length(particles)

    ## precompute linear kernel values
    mpvalues = map(eachindex(particles)) do p
        mp = MPValues(Vec{2}, LinearBSpline())
        update!(mp, particles[p], grid.X)
        mp
    end

    ## outputs
    outdir = mkpath(joinpath("output.tmp", "tlmpm_vortex"))
    pvdfile = joinpath(outdir, "paraview")
    closepvd(openpvd(pvdfile)) # create file

    t::Float64 = 0.0
    step::Int = 0
    fps = 60
    savepoints = collect(LinRange(t, t_stop, round(Int, t_stop*fps)+1))

    Sequoia.@showprogress while t < t_stop

        ## calculate timestep based on the wave speed of elastic material
        Δt = CFL * spacing(grid) / maximum(LazyRows(particles)) do pt
            ρ = pt.m / (pt.V⁰ * det(pt.F))
            vc = √((λ+2μ) / ρ)
            vc + norm(pt.v)
        end

        ## compute grid body forces
        for i in eachindex(grid)
            if isinside(grid.X[i])
                (x, y) = grid.X[i]
                R = sqrt(x^2 + y^2)
                θ = atan(y, x)
                grid.b[i] = rotmat(θ) ⋅ calc_b_Rθ(R, t)
            end
        end

        @P2G grid=>i particles=>p mpvalues=>ip begin
            m[i]    = @∑ N[ip] * m[p]
            mv[i]   = @∑ N[ip] * m[p] * v[p]
            fint[i] = @∑ -V⁰[p] * P[p] ⋅ ∇N[ip]
        end

        @. grid.m⁻¹  = inv(grid.m) * !iszero(grid.m)
        @. grid.fext = grid.m * grid.b
        @. grid.vⁿ   = grid.mv * grid.m⁻¹
        @. grid.v    = grid.vⁿ + Δt * (grid.fint + grid.fext) * grid.m⁻¹
        grid.v[outside_gridinds] .= zero(eltype(grid.v))

        ## update particle velocity and position
        @G2P grid=>i particles=>p mpvalues=>ip begin
            ṽ[p]  = @∑ v[i] * N[ip]
            ã[p]  = @∑ (v[i] - vⁿ[i])/Δt * N[ip]
            v[p]  = (1-α)*ṽ[p] + α*(v[p] + Δt*ã[p])
            x[p] += Δt * ṽ[p]
        end

        ## remap updated velocity to grid (MUSL)
        @P2G grid=>i particles=>p mpvalues=>ip begin
            mv[i] = @∑ N[ip] * m[p] * v[p]
            v[i]  = mv[i] * m⁻¹[i]
        end
        grid.v[outside_gridinds] .= zero(eltype(grid.v))

        ## update stress
        @G2P grid=>i particles=>p mpvalues=>ip begin
            F[p] += @∑ Δt * v[i] ⊗ ∇N[ip]
            P[p]  = μ * (F[p] - inv(F[p])') + λ * log(det(F[p])) * inv(F[p])'
        end

        t += Δt
        step += 1

        if t > first(savepoints)
            popfirst!(savepoints)
            openpvd(pvdfile; append=true) do pvd
                openvtm(string(pvdfile, step)) do vtm
                    angle(x) = atan(x[2], x[1])
                    openvtk(vtm, particles.x) do vtk
                        vtk["velocity"] = particles.v
                        vtk["initial angle"] = angle.(particles.X)
                    end
                    openvtk(vtm, grid.X) do vtk
                        vtk["external force"] = grid.fext
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
    @test tlmpm_vortex() < 1e-8       #src
end                                   #src
