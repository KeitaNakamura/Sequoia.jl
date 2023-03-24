# # Dam-break
#
# ![](https://user-images.githubusercontent.com/16015926/225801067-2194bf27-2482-45c6-9750-b907cfa17497.gif)

using Marble
using StableRNGs #src

function dam_break(
        itp::Interpolation = KernelCorrection(QuadraticBSpline()),
        alg::TransferAlgorithm = TPIC(),
        ;output::Bool = true, #src
        test::Bool = false,   #src
    )

    ## simulation parameters
    t_stop = 3.0   # time for simulation
    g      = 9.81  # gravity acceleration
    CFL    = 0.1   # Courant number
    ## use low resolution for testing purpose #src
    if test                                   #src
        dx::Float64 = 0.07                    #src
    else                                      #src
    dx     = 0.014 # grid spacing
    end                                       #src

    ## material constants for water
    ρ₀ = 1.0e3   # initial density
    μ  = 1.01e-3 # dynamic viscosity (Pa⋅s)
    c  = 60.0    # speed of sound (m/s)

    ## states for grid and particles
    GridState = @NamedTuple begin
        x  :: Vec{2, Float64}
        m  :: Float64
        mv :: Vec{2, Float64}
        f  :: Vec{2, Float64}
        v  :: Vec{2, Float64}
        vⁿ :: Vec{2, Float64}
    end
    ParticleState = @NamedTuple begin
        x  :: Vec{2, Float64}
        m  :: Float64
        V  :: Float64
        v  :: Vec{2, Float64}
        ∇v :: SecondOrderTensor{3, Float64, 9}
        σ  :: SymmetricSecondOrderTensor{3, Float64, 6}
        b  :: Vec{2, Float64}
        l  :: Float64                          # for uGIMP
        B  :: SecondOrderTensor{2, Float64, 4} # for APIC
        C  :: Mat{2, 3, Float64, 6}            # for WLS
    end

    ## grid
    grid = generate_grid(GridState, dx, (0,3.22), (0,4.0))

    ## particles
    if test                                                                                          #src
        particles::Marble.infer_particles_type(ParticleState) =                                      #src
            generate_particles((x,y) -> x<1.2 && y<0.6, ParticleState, grid; random=StableRNG(1234)) #src
    else                                                                                             #src
    particles = generate_particles((x,y) -> x<1.2 && y<0.6, ParticleState, grid; random=true)
    end                                                                                              #src
    @. particles.m = ρ₀ * particles.V
    @. particles.b = Vec(0, -g)
    @show length(particles)

    ## create interpolation space
    space = MPSpace(itp, size(grid), length(particles))

    ## outputs
    pvdfile = joinpath(mkpath("Output.tmp"), "dam_break")
    closepvd(openpvd(pvdfile))

    t = 0.0
    step = 0
    fps = 50
    savepoints = collect(LinRange(t, t_stop, round(Int, t_stop*fps)+1))
    while t < t_stop

        ## calculate timestep based on the Courant-Friedrichs-Lewy (CFL) condition
        Δt = CFL * minimum(LazyRows(particles)) do pt
            ρ = pt.m / pt.V
            ν = μ / ρ # kinemtatic viscosity
            min(dx/(c+norm(pt.v)), dx^2/ν)
        end

        ## update interpolation space
        update!(space, grid, particles)

        ## P2G transfer
        particle_to_grid!((:m,:mv,:f), fillzero!(grid), particles, space; alg)

        ## solve momentum equation
        @. grid.vⁿ = grid.mv / grid.m * !iszero(grid.m)
        @. grid.v = grid.vⁿ + Δt*(grid.f/grid.m) * !iszero(grid.m)

        ## boundary conditions
        gridindices_floor = @view eachindex(grid)[:, begin]
        gridindices_walls = @view eachindex(grid)[[begin, end],:]
        slip(vᵢ, n) = vᵢ - (vᵢ⋅n)*n
        @inbounds for i in gridindices_floor
            grid.v[i] = slip(grid.v[i], Vec(0,1))
        end
        @inbounds for i in gridindices_walls
            grid.v[i] = slip(grid.v[i], Vec(1,0))
        end

        ## G2P transfer
        grid_to_particle!((:v,:∇v,:x), particles, grid, space, Δt; alg)

        ## update other particle states
        Marble.@threaded_inbounds for pt in LazyRows(particles)
            d = symmetric(pt.∇v)
            V = pt.V * exp(tr(d)*Δt)
            ρ = pt.m / V
            p = c^2 * (ρ - ρ₀)
            pt.σ = -p*I + 2μ*dev(d)
            pt.V = V
        end

        t += Δt
        step += 1

        if output #src
        if t > first(savepoints)
            popfirst!(savepoints)
            openpvd(pvdfile; append=true) do pvd
                openvtk(string(pvdfile, step), particles.x) do vtk
                    vorticity(∇v) = ∇v[2,1] - ∇v[1,2]
                    vtk["vorticity"] = @. vorticity(particles.∇v)
                    pvd[t] = vtk
                end
            end
        end
        end #src
    end
    particles #src
end

## check the result                                                                                                                                  #src
using Test                                                                                                                                           #src
@test mean(dam_break(KernelCorrection(QuadraticBSpline()), TPIC(); output=false, test=true).x) ≈ [1.6289726447675077, 0.11321605792384627] rtol=1e-5 #src
@test mean(dam_break(KernelCorrection(QuadraticBSpline()), APIC(); output=false, test=true).x) ≈ [1.6294993733786765, 0.11320682736922087] rtol=1e-5 #src
@test mean(dam_break(KernelCorrection(QuadraticBSpline()), FLIP(); output=false, test=true).x) ≈ [1.482050336414871, 0.13076917336964955]  rtol=1e-5 #src
@test mean(dam_break(LinearWLS(QuadraticBSpline()),        TPIC(); output=false, test=true).x) ≈ [1.637148881940021, 0.11354987067566219]  rtol=1e-5 #src
@test mean(dam_break(LinearWLS(QuadraticBSpline()), WLSTransfer(); output=false, test=true).x) ≈ [1.637148881940021, 0.11354987067566219]  rtol=1e-5 #src