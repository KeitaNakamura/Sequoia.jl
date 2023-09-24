"""
Marble.jl supports following transfer algorithms:

* Basic transfers: [`FLIP`](@ref), [`PIC`](@ref)
* Affine transfers: [`AFLIP`](@ref), [`APIC`](@ref)
* Taylor transfers: [`TFLIP`](@ref), [`TPIC`](@ref)
"""
abstract type TransferAlgorithm end

"""
    FLIP()

FLIP (fluid-implicit-particle) transfer algorithm [^FLIP]. This algorithm is widely used as
the standard MPM formulation. The FLIP transfer is less dissipative but also less stable
than [`PIC`](@ref) (particle-in-cell) transfer.

[^FLIP]: [Brackbill, J. U., & Ruppel, H. M. (1986). FLIP: A method for adaptively zoned, particle-in-cell calculations of fluid flows in two dimensions. *Journal of Computational physics*, 65(2), 314-343.](https://doi.org/10.1016/0021-9991(86)90211-1)

# Particle-to-grid transfer

```math
\\begin{aligned}
m_i^n &= \\sum_p N_{ip}^n m_p \\\\
m_i^n \\bm{v}_i^n &= \\sum_p N_{ip}^n m_p \\bm{v}_p^n \\\\
\\bm{f}_i^n &= -\\sum_p V_p^n \\bm{\\sigma}_p^n \\cdot \\nabla N_{ip}^n + \\sum_p N_{ip}^n m_p \\bm{b}_p \\\\
\\end{aligned}
```

The required properties in [`particle_to_grid!`](@ref) are follows:

- ``m_i^n`` : `grid.m :: Real`
    * ``m_p`` : `particles.m :: Real`
- ``m_i^n\\bm{v}_i^n`` : `grid.mv :: Vec`:
    * ``m_p`` : `particles.m :: Real`
    * ``\\bm{v}_p^n`` : `particles.v :: Vec`
- ``\\bm{f}_i^n`` : `grid.f :: Vec`
    * ``V_p^n`` : `particles.V :: Real`
    * ``\\bm{\\sigma}_p^n`` :  `particles.σ :: SymmetricSecondOrderTensor`
    * ``\\bm{b}_p`` (considered if exists) : `particles.b :: Vec`

# Grid-to-particle transfer

```math
\\begin{aligned}
\\bm{v}_p^{n+1} &= \\bm{v}_p^n + \\sum_i N_{ip}^n (\\bm{v}_i^{n+1} - \\bm{v}_i^n) \\\\
\\nabla\\bm{v}_p^{n+1} &= \\sum_i \\bm{v}_i^{n+1} \\otimes \\nabla N_{ip}^n \\\\
\\bm{x}_p^{n+1} &= \\bm{x}_p^n + \\Delta{t} \\sum_i N_{ip}^n \\bm{v}_i^{n+1}
\\end{aligned}
```

The required properties in [`grid_to_particle!`](@ref) are follows:

- ``\\bm{v}_p^{n+1}`` : `particles.v :: Vec`
    * ``\\bm{v}_i^{n+1}`` : `grid.v :: Vec`
    * ``\\bm{v}_i^{n}`` : `grid.vⁿ :: Vec` (type `v\\^n[tab]`)
- ``\\nabla\\bm{v}_p^{n+1}`` : `particles.∇v :: Vec` (type `\\nabla[tab]` for `∇`)
    * ``\\bm{v}_i^{n+1}`` : `grid.v :: Vec`
- ``\\bm{x}_p^{n+1}`` : `particles.x :: Vec`
    * ``\\bm{v}_i^{n+1}`` : `grid.v :: Vec`
"""
struct FLIP <: TransferAlgorithm end

struct FLIP_PIC_Blends <: TransferAlgorithm
    α::Float64
end

FLIP(α::Real) = FLIP_PIC_Blends(α)

"""
    PIC()

PIC (particle-in-cell) transfer algorithm [^PIC]. This algorithm is well known as the transfer
from PIC method. The PIC transfer is more stable than [`FLIP`](@ref), but produces very
dissipative behaviors. It is basically recommended to use PIC with [`AffineTransfer`](@ref)
or [`TPIC`](@ref) transfers.

[^PIC]: [Harlow, F. H. (1964). The particle-in-cell computing method for fluid dynamics. *Methods Comput. Phys.*, 3, 319-343.](https://doi.org/10.2172/4769185)

# Particle-to-grid transfer

```math
\\begin{aligned}
m_i^n &= \\sum_p N_{ip}^n m_p \\\\
m_i^n \\bm{v}_i^n &= \\sum_p N_{ip}^n m_p \\bm{v}_p^n \\\\
\\bm{f}_i^n &= -\\sum_p V_p^n \\bm{\\sigma}_p^n \\cdot \\nabla N_{ip}^n + \\sum_p N_{ip}^n m_p \\bm{b}_p
\\end{aligned}
```

## Required properties in [`particle_to_grid!`](@ref)

- ``m_i^n`` : `grid.m :: Real`
    * ``m_p`` : `particles.m :: Real`
- ``m_i^n\\bm{v}_i^n`` : `grid.mv :: Vec`:
    * ``m_p`` : `particles.m :: Real`
    * ``\\bm{v}_p^n`` : `particles.v :: Vec`
- ``\\bm{f}_i^n`` : `grid.f :: Vec`
    * ``V_p^n`` : `particles.V :: Real`
    * ``\\bm{\\sigma}_p^n`` :  `particles.σ :: SymmetricSecondOrderTensor`
    * ``\\bm{b}_p`` (considered if exists) : `particles.b :: Vec`

# Grid-to-particle transfer

```math
\\begin{aligned}
\\bm{v}_p^{n+1} &= \\sum_i N_{ip}^n \\bm{v}_i^{n+1} \\\\
\\nabla\\bm{v}_p^{n+1} &= \\sum_i \\bm{v}_i^{n+1} \\otimes \\nabla N_{ip}^n \\\\
\\bm{x}_p^{n+1} &= \\bm{x}_p^n + \\Delta{t} \\bm{v}_p^{n+1}
\\end{aligned}
```

## Required properties in [`grid_to_particle!`](@ref)

- ``\\bm{v}_p^{n+1}`` : `particles.v :: Vec`
    * ``\\bm{v}_i^{n+1}`` : `grid.v :: Vec`
- ``\\nabla\\bm{v}_p^{n+1}`` : `particles.∇v :: Vec` (type `\\nabla[tab]` for `∇`)
    * ``\\bm{v}_i^{n+1}`` : `grid.v :: Vec`
- ``\\bm{x}_p^{n+1}`` : `particles.x :: Vec`
    * ``\\bm{v}_i^{n+1}`` : `grid.v :: Vec`
"""
struct PIC <: TransferAlgorithm end

"""
    AffineTransfer(basic)

Affine transfer algorithm [^Affine]. Currently `basic` should be [`FLIP()`](@ref) or [`PIC()`](@ref).
There are also abbreviated forms [`AFLIP()`](@ref) and [`APIC()`](@ref), respectively.
Only differences with `basic` transfer are summarized below.

[^Affine]: [Jiang, C., Schroeder, C., Selle, A., Teran, J., & Stomakhin, A. (2015). The affine particle-in-cell method. *ACM Transactions on Graphics (TOG)*, 34(4), 1-10.](https://doi.org/10.1145/2766996)

# Particle-to-grid transfer

```math
m_i^n \\bm{v}_i^n = \\sum_p N_{ip}^n m_p \\left( \\bm{v}_p^n + \\bm{B}_p^n \\cdot (\\bm{D}_p^n)^{-1} \\cdot (\\bm{x}_i - \\bm{x}_p^n) \\right) \\\\
```

where

```math
\\bm{D}_p^n = \\sum_i N_{ip}^n (\\bm{x}_i - \\bm{x}_p^n) \\otimes (\\bm{x}_i - \\bm{x}_p^n)
```

## Required properties in [`particle_to_grid!`](@ref)

- ``m_i^n\\bm{v}_i^n`` : `grid.mv :: Vec`:
    * ``m_p`` : `particles.m :: Real`
    * ``\\bm{v}_p^n`` : `particles.v :: Vec`
    * ``\\bm{B}_p^n`` : `particles.B :: SecondOrderTensor`

# Grid-to-particle transfer

Addition to `basic` transfer, ``\\bm{B}_p`` must be updated as

```math
\\bm{B}_p^{n+1} = \\sum_i N_{ip}^n \\bm{v}_i^{n+1} \\otimes (\\bm{x}_i - \\bm{x}_p^n)
```

## Required properties in [`grid_to_particle!`](@ref)

- ``\\bm{B}_p^{n+1}`` : `particles.B :: SecondOrderTensor`:
    * ``\\bm{v}_i^{n+1}`` : `grid.v :: Vec`

!!! note
    ``\\bm{B}_p`` is automatically updated when ``\\bm{v}_p`` is updated.
    Check also `basic` transfer.
"""
struct AffineTransfer{T <: Union{FLIP, PIC}} <: TransferAlgorithm end
AffineTransfer(t::TransferAlgorithm) = AffineTransfer{typeof(t)}()

"""
    const AFLIP = AffineTransfer{FLIP}

See [`AffineTransfer`](@ref).
"""
const AFLIP = AffineTransfer{FLIP}

"""
    const APIC = AffineTransfer{PIC}

See [`AffineTransfer`](@ref).
"""
const APIC  = AffineTransfer{PIC}

"""
    TaylorTransfer(basic)

Taylor transfer algorithm [^Taylor]. Currently `basic` should be [`FLIP()`](@ref) or [`PIC()`](@ref).
There are also abbreviated forms [`TFLIP()`](@ref) and [`TPIC()`](@ref), respectively.
Only different transfer equations with `basic` transfer are summarized below.

[^Taylor]: [Nakamura, K., Matsumura, S., & Mizutani, T. (2023). Taylor particle-in-cell transfer and kernel correction for material point method. *Computer Methods in Applied Mechanics and Engineering*, 403, 115720.](https://doi.org/10.1016/j.cma.2022.115720)

# Particle-to-grid transfer

```math
m_i^n \\bm{v}_i^n = \\sum_p N_{ip}^n m_p \\left( \\bm{v}_p^n + \\nabla\\bm{v}_p^n \\cdot (\\bm{x}_i - \\bm{x}_p^n) \\right)
```

## Required properties in [`particle_to_grid!`](@ref)

- ``m_i^n\\bm{v}_i^n`` : `grid.mv :: Vec`:
    * ``m_p`` : `particles.m :: Real`
    * ``\\bm{v}_p^n`` : `particles.v :: Vec`
    * ``\\nabla\\bm{v}_p^n`` : `particles.∇v :: SecondOrderTensor` (type `\\nabla[tab]` for `∇`)

# Grid-to-particle transfer

Same as the `basic` transfer.
"""
struct TaylorTransfer{T <: Union{FLIP, PIC}} <: TransferAlgorithm end
TaylorTransfer(t::TransferAlgorithm) = TaylorTransfer{typeof(t)}()

"""
    const TFLIP = TaylorTransfer{FLIP}

See [`TaylorTransfer`](@ref).
"""
const TFLIP = TaylorTransfer{FLIP}

"""
    const TPIC = TaylorTransfer{PIC}

See [`TaylorTransfer`](@ref).
"""
const TPIC  = TaylorTransfer{PIC}

"""
    WLSTransfer()

The special transfer for [`WLS`](@ref) interpolation.
Using this transfer with [`WLS`](@ref) interpolation becomse the MLS-MPM [^MLSMPM].

[^MLSMPM]: [Hu, Y., Fang, Y., Ge, Z., Qu, Z., Zhu, Y., Pradhana, A., & Jiang, C. (2018). A moving least squares material point method with displacement discontinuity and two-way rigid body coupling. *ACM Transactions on Graphics (TOG)*, 37(4), 1-14.](https://doi.org/10.1145/3197517.3201293)
"""
struct WLSTransfer <: TransferAlgorithm end

const FLIPGroup = Union{FLIP, AFLIP, TFLIP}
const PICGroup = Union{PIC, APIC, TPIC}

###########
# helpers #
###########

function check_particles(particles::AbstractVector, space::MPSpace)
    @assert length(particles) == num_particles(space)
end

function check_grid(grid::Grid, space::MPSpace)
    @assert size(grid) == gridsize(space)
end
function check_grid(grid::Union{SpGrid, SpArray}, space::MPSpace)
    @assert size(grid) == gridsize(space)
    get_spinds(grid) !== get_gridspinds(space) &&
        error("Using different sparsity pattern between `MPSpace` and `Grid`")
end

function check_statenames(part::Tuple{Vararg{Symbol}}, all::Tuple{Vararg{Symbol}})
    isempty(setdiff!(Set(part), Set(all))) || error("unsupported state names, got $part, available names are $all")
end

################
# P2G transfer #
################

"""
    particle_to_grid!(list, grid, particles, space; alg::TransferAlgorithm, system)

Transfer the particle states to the grid.

`list` is a tuple of names that you want to transfer. The available state names are
`:m` (mass), `:mv` (momentum) and `:f` (force). `grid` and `particles` have some
required properties that will be accessed via `getproperty`, which depends on the
transfer algorithms. See each algorithm in [`TransferAlgorithm`](@ref) for more details.

!!! note "Axisymmetric case"
    If you set `system = Axisymmetric()` in two dimensional case, `particles.x[p][1]`
    is used for the radius position of the particle `p`.
"""
function particle_to_grid!(names::Tuple{Vararg{Symbol}}, grid::Grid, particles::Particles, space::MPSpace, args...; kwargs...)
    particle_to_grid!(Val(names), grid, particles, space, args...; kwargs...)
end
function particle_to_grid!(name::Symbol, grid::Grid, particles::Particles, space::MPSpace, args...; kwargs...)
    particle_to_grid!(Val((name,)), grid, particles, space, args...; kwargs...)
end

function particle_to_grid!(::Val{names}, grid::Grid, particles::Particles, space::MPSpace; alg::TransferAlgorithm, system::CoordinateSystem=DefaultSystem(), parallel::Bool=true) where {names}
    check_statenames(names, (:m, :mv, :f, :fint, :fext, :∇m))
    check_grid(grid, space)
    check_particles(particles, space)
    blockwise_parallel_each_particle(space, :dynamic; parallel) do p
        @inbounds particle_to_grid!(alg, system, Val(names), grid, LazyRow(particles, p), get_interpolation(space), values(space, p))
    end
    grid
end

# don't use dispatch and all transfer algorithms are writtein in this function to reduce a lot of deplicated code
@inline function particle_to_grid!(alg::TransferAlgorithm, system::CoordinateSystem, ::Val{names}, grid::Grid, pt, itp::Interpolation, mp::SubMPValues{dim, T}) where {names, dim, T}
    @_propagate_inbounds_meta

    gridindices = neighbornodes(mp, grid)

    if :m in names || :∇m in names
        mₚ = pt.m
    end

    if :f in names || :fint in names
        Vₚσₚ = pt.V * pt.σ
        if system isa Axisymmetric
            rₚ = pt.x[1]
        end
    end

    if :f in names || :fext in names
        if hasproperty(pt, :b)
            mₚbₚ = pt.m * pt.b
        end
    end

    # grid momentum depends on transfer algorithms
    if :mv in names
        if alg isa WLSTransfer && itp isa WLS
            P = x -> value(get_basis(itp), x)
            xₚ = pt.x
            mₚCₚ = pt.m * pt.C
        else
            mₚvₚ = pt.m * pt.v

            # additional term for advanced approximation
            if alg isa AffineTransfer
                xₚ = pt.x
                Dₚ = zero(Mat{dim, dim, T})
                @simd for j in CartesianIndices(gridindices)
                    i = gridindices[j]
                    N = mp.N[j]
                    xᵢ = grid.x[i]
                    Dₚ += N*(xᵢ-xₚ)⊗(xᵢ-xₚ)
                end
                mₚCₚ = pt.m * pt.B ⋅ inv(Dₚ)
            elseif alg isa TaylorTransfer
                xₚ = pt.x
                mₚ∇vₚ = pt.m * @Tensor(pt.∇v[1:dim, 1:dim])
            end
        end
    end

    @simd for j in CartesianIndices(gridindices)
        i = gridindices[j]
        N = mp.N[j]
        ∇N = mp.∇N[j]

        if :m in names
            grid.m[i] += N*mₚ
        end

        if :∇m in names
            grid.∇m[i] += ∇N*mₚ
        end

        if :f in names || :fint in names
            if system isa Axisymmetric
                fint = calc_fint(system, N, ∇N, Vₚσₚ, rₚ)
            else
                fint = calc_fint(system, ∇N, Vₚσₚ)
            end
            :f    in names && (grid.f[i]    -= fint)
            :fint in names && (grid.fint[i] += fint)
        end

        if :f in names || :fext in names
            if hasproperty(pt, :b)
                fext = N*mₚbₚ
                :f    in names && (grid.f[i]    += fext)
                :fext in names && (grid.fext[i] += fext)
            end
        end

        # grid momentum depends on transfer algorithms
        if :mv in names
            xᵢ = grid.x[i]
            if alg isa WLSTransfer && itp isa WLS
                grid.mv[i] += N*mₚCₚ⋅P(xᵢ-xₚ)
            elseif alg isa AffineTransfer
                grid.mv[i] += N*(mₚvₚ + mₚCₚ⋅(xᵢ-xₚ))
            elseif alg isa TaylorTransfer
                grid.mv[i] += N*(mₚvₚ + mₚ∇vₚ⋅(xᵢ-xₚ))
            else
                grid.mv[i] += N*mₚvₚ
            end
        end
    end
end

function particle_to_grid!(::Val{(:g,)}, grid::Grid, particles::Particles, space::MPSpace, gap_function)
    check_grid(grid, space)
    check_particles(particles, space)

    mask = falses(size(grid))
    @inbounds for p in 1:length(particles)
        pt = LazyRow(particles, p)
        mₚ = pt.m
        gₚ = gap_function(pt)
        gₚ === nothing && continue

        mp = values(space, p)
        gridindices = neighbornodes(mp, grid)
        @simd for j in CartesianIndices(gridindices)
            i = gridindices[j]
            N = mp.N[j]
            grid.g[i] += N*mₚ*gₚ
            mask[i] = true
        end
    end

    findall(mask)
end

# 1D
@inline calc_fint(::DefaultSystem, ∇N::Vec{1}, Vₚσₚ::AbstractSquareTensor{1}) = Vₚσₚ ⋅ ∇N
# plane-strain
@inline calc_fint(::Union{DefaultSystem, PlaneStrain}, ∇N::Vec{2}, Vₚσₚ::AbstractSquareTensor{3}) = @Tensor(Vₚσₚ[1:2,1:2]) ⋅ ∇N
@inline calc_fint(::Union{DefaultSystem, PlaneStrain}, ∇N::Vec{2}, Vₚσₚ::AbstractSquareTensor{2}) = Vₚσₚ ⋅ ∇N
# axisymmetric
@inline calc_fint(::Axisymmetric, N::Real, ∇N::Vec{2}, Vₚσₚ::AbstractSquareTensor{3}, rₚ::Real) = @Tensor(Vₚσₚ[1:2,1:2])⋅∇N + Vec(1,0)*Vₚσₚ[3,3]*N/rₚ
# 3D
@inline calc_fint(::DefaultSystem, ∇N::Vec{3}, Vₚσₚ::AbstractSquareTensor{3}) = Vₚσₚ ⋅ ∇N

################
# G2P transfer #
################

"""
    grid_to_particle!(list, particles, grid, space[, dt]; alg::TransferAlgorithm, system)

Transfer the grid states to the particles.

`list` is a tuple of names that you want to transfer. The available state names are
`:v` (velocity), `:∇v` (velocity gradient; type `\\nabla[tab]` for `∇`) and `:x`
(position). `grid` and `particles` have some required properties that will be accessed
via `getproperty`, which depends on the transfer algorithms. See each algorithm in
[`TransferAlgorithm`](@ref) for more details.

!!! note "Axisymmetric case"
    If you set `system = Axisymmetric()` in two dimensional case, `particles.x[p][1]`
    is used for the radius position of the particle `p`.
"""
function grid_to_particle!(names, particles::Particles, grid::Grid, space::MPSpace, args...; kwargs...)
    grid_to_particle!(identity, names, particles, grid, space, args...; kwargs...)
end

function grid_to_particle!(do_particle!, names::Tuple{Vararg{Symbol}}, particles::Particles, grid::Grid, space::MPSpace, args...; kwargs...)
    grid_to_particle!(do_particle!, Val(names), particles, grid, space, args...; kwargs...)
end
function grid_to_particle!(do_particle!, name::Symbol, particles::Particles, grid::Grid, space::MPSpace, args...; kwargs...)
    grid_to_particle!(do_particle!, Val((name,)), particles, grid, space, args...; kwargs...)
end

function grid_to_particle!(do_particle!, ::Val{names}, particles::Particles, grid::Grid, space::MPSpace, args...; alg::TransferAlgorithm, system::CoordinateSystem=DefaultSystem(), parallel::Bool=true, kwargs...) where {names}
    grid_to_particle!(do_particle!, alg, system, Val(names), particles, grid, space, args...; parallel, kwargs...)
end

function grid_to_particle!(do_particle!, alg::TransferAlgorithm, system::CoordinateSystem, ::Val{names}, particles::Particles, grid::Grid, space::MPSpace{dim}, only_dt...; parallel::Bool) where {names, dim}
    @assert length(only_dt) == 0 || length(only_dt) == 1
    check_statenames(names, (:v, :∇v, :x))
    check_grid(grid, space)
    check_particles(particles, space)
    parallel_foreach(1:num_particles(space), :dynamic; ntasks=ifelse(parallel, Threads.nthreads(), 1)) do p
        @inbounds begin
            pt = LazyRow(particles, p)
            grid_to_particle!(alg, system, Val(names), pt, grid, get_interpolation(space), values(space, p), only_dt...)
            do_particle!(pt)
        end
    end
    particles
end

@inline function grid_to_particle!(alg::TransferAlgorithm, system::CoordinateSystem, ::Val{names}, pt, grid::Grid, itp::Interpolation, mp::SubMPValues{dim, T}, only_dt...) where {names, dim, T}
    @_propagate_inbounds_meta

    # there is no difference along with transfer algorithms for calculating `:∇v` and `:x`
    if :∇v in names
        ∇vₚ = @Tensor zero(pt.∇v)[1:dim, 1:dim]
        if system isa Axisymmetric
            vₚ = zero(pt.v)
        end
    end

    if :x in names
        if hasproperty(grid, :xⁿ⁺¹)
            xₚⁿ⁺¹ = zero(pt.x)
        else
            vₚ = zero(pt.v)
        end
    end

    # particle velocity depends on transfer algorithms
    if :v in names
        if alg isa FLIPGroup
            dvₚ = zero(pt.v)
        elseif alg isa PICGroup
            vₚ = zero(pt.v)
        elseif alg isa FLIP_PIC_Blends
            dvₚ = zero(pt.v)
            vₚ = zero(pt.v)
        else
            error("unreachable")
        end
        if alg isa AffineTransfer
            # Bₚ is always calculated when `:v` is specified
            xₚ = pt.x
            Bₚ = zero(pt.B)
        end
    end

    gridindices = neighbornodes(mp, grid)
    @simd for j in CartesianIndices(gridindices)
        i = gridindices[j]
        N = mp.N[j]
        ∇N = mp.∇N[j]

        # 100% used
        vᵢ = grid.v[i]

        if :∇v in names
            ∇vₚ += vᵢ ⊗ ∇N
        end

        if :x in names
            if hasproperty(grid, :xⁿ⁺¹)
                xᵢⁿ⁺¹ = grid.xⁿ⁺¹[i]
                xₚⁿ⁺¹ += xᵢⁿ⁺¹ * N
            end
        end

        # use `@isdefined` to avoid complicated check
        # for `:v` in `PIC` is also calculated here
        if @isdefined vₚ
            vₚ += vᵢ * N
        end

        # particle velocity depends on transfer algorithms
        if :v in names
            if alg isa FLIPGroup || alg isa FLIP_PIC_Blends
                dvᵢ = vᵢ - grid.vⁿ[i]
                dvₚ += N * dvᵢ
            end
            if alg isa AffineTransfer
                xᵢ = grid.x[i]
                Bₚ += N * vᵢ ⊗ (xᵢ - xₚ)
            end
        end
    end

    if :∇v in names
        if system isa Axisymmetric
            pt.∇v = calc_∇v(system, typeof(pt.∇v), ∇vₚ, vₚ[1], pt.x[1])
        else
            pt.∇v = calc_∇v(system, typeof(pt.∇v), ∇vₚ)
        end
    end

    if :x in names
        if hasproperty(grid, :xⁿ⁺¹)
            pt.x = xₚⁿ⁺¹
        else
            dt = only(only_dt)
            pt.x += vₚ * dt
        end
    end

    # particle velocity depends on transfer algorithms
    if :v in names
        if alg isa FLIPGroup
            pt.v += dvₚ
        elseif alg isa PICGroup
            pt.v = vₚ
        elseif alg isa FLIP_PIC_Blends
            v_FLIP = pt.v + dvₚ
            v_PIC = vₚ
            α = convert(T, alg.α)
            pt.v = α*v_FLIP + (1-α)*v_PIC
        else
            error("unreachable")
        end
        if alg isa AffineTransfer
            # additional quantity for affine transfers
            # Bₚ is always calculated when `:v` is specified
            pt.B = Bₚ
        end
    end
end

# special transfer for `WLS` interpolation
@inline function grid_to_particle!(::WLSTransfer, system::CoordinateSystem, ::Val{names}, pt, grid::Grid, itp::WLS, mp::SubMPValues{dim}, only_dt...) where {names, dim}
    @_propagate_inbounds_meta

    basis = get_basis(itp)
    P = x -> value(basis, x)
    p0 = value(basis, zero(Vec{dim, Int}))
    ∇p0 = gradient(basis, zero(Vec{dim, Int}))

    xₚ = pt.x
    Cₚ = zero(pt.C)

    if :x in names
        if hasproperty(grid, :xⁿ⁺¹)
            xₚⁿ⁺¹ = zero(pt.x)
        end
    end

    gridindices = neighbornodes(mp, grid)
    @simd for j in CartesianIndices(gridindices)
        i = gridindices[j]
        w = mp.w[j]
        Minv = mp.Minv[]
        vᵢ = grid.v[i]
        xᵢ = grid.x[i]
        Cₚ += vᵢ ⊗ (w * Minv ⋅ P(xᵢ - xₚ))

        if :x in names
            if hasproperty(grid, :xⁿ⁺¹)
                N = mp.N[j]
                xᵢⁿ⁺¹ = grid.xⁿ⁺¹[i]
                xₚⁿ⁺¹ += xᵢⁿ⁺¹ * N
            end
        end
    end

    vₚ = Cₚ ⋅ p0

    if :∇v in names
        ∇vₚ = Cₚ ⋅ ∇p0
        if system isa Axisymmetric
            pt.∇v = calc_∇v(system, typeof(pt.∇v), ∇vₚ, vₚ[1], pt.x[1])
        else
            pt.∇v = calc_∇v(system, typeof(pt.∇v), ∇vₚ)
        end
    end

    if :x in names
        if hasproperty(grid, :xⁿ⁺¹)
            pt.x = xₚⁿ⁺¹
        else
            dt = only(only_dt)
            pt.x += vₚ * dt
        end
    end

    if :v in names
        pt.v = vₚ
        pt.C = Cₚ # always update when velocity is updated
    end
end

# 1D
@inline calc_∇v(::DefaultSystem, ::Type{<: SecondOrderTensor{1}}, ∇vₚ::SecondOrderTensor{1}) = ∇vₚ
# plane-strain
@inline calc_∇v(::Union{DefaultSystem, PlaneStrain}, ::Type{<: SecondOrderTensor{2}}, ∇vₚ::SecondOrderTensor{2}) = ∇vₚ
@inline calc_∇v(::Union{DefaultSystem, PlaneStrain}, ::Type{<: SecondOrderTensor{3}}, ∇vₚ::SecondOrderTensor{2}) = Tensorial.resizedim(∇vₚ, Val(3))
# axisymmetric
@inline calc_∇v(::Axisymmetric, ::Type{<: SecondOrderTensor{3}}, ∇vₚ::SecondOrderTensor{2}, vₚ::Real, rₚ::Real) = Tensorial.resizedim(∇vₚ, Val(3)) + @Mat([0 0 0; 0 0 0; 0 0 vₚ/rₚ])
# 3D
@inline calc_∇v(::DefaultSystem, ::Type{<: SecondOrderTensor{3}}, ∇vₚ::SecondOrderTensor{3}) = ∇vₚ

##########################
# smooth_particle_state! #
##########################

@generated function safe_inv(x::Mat{dim, dim, T, L}) where {dim, T, L}
    exps = fill(:z, L-1)
    quote
        @_inline_meta
        z = zero(T)
        isapproxzero(det(x)) ? Mat{dim, dim}(inv(x[1]), $(exps...)) : inv(x)
        # Tensorial.rank(x) != dim ? Mat{dim, dim}(inv(x[1]), $(exps...)) : inv(x) # this is very slow but stable
    end
end

function smooth_particle_state!(vals::AbstractVector, xₚ::AbstractVector, Vₚ::AbstractVector, grid::Grid, space::MPSpace; parallel::Bool=true)
    check_grid(grid, space)
    check_particles(vals, space)
    check_particles(xₚ, space)
    check_particles(Vₚ, space)

    basis = PolynomialBasis{1}()
    fillzero!(grid.poly_coef)
    fillzero!(grid.poly_mat)

    blockwise_parallel_each_particle(space, :dynamic; parallel) do p
        @inbounds begin
            mp = values(space, p)
            gridindices = neighbornodes(mp, grid)
            @simd for j in CartesianIndices(gridindices)
                i = gridindices[j]
                N = mp.N[j]
                P = value(basis, xₚ[p] - grid.x[i])
                VP = (N * Vₚ[p]) * P
                grid.poly_coef[i] += VP * vals[p]
                grid.poly_mat[i]  += VP ⊗ P
            end
        end
    end

    @. grid.poly_coef = safe_inv(grid.poly_mat) ⋅ grid.poly_coef

    parallel_foreach(1:num_particles(space), :dynamic; ntasks=ifelse(parallel, Threads.nthreads(), 1)) do p
        @inbounds begin
            val = zero(eltype(vals))
            mp = values(space, p)
            gridindices = neighbornodes(mp, grid)
            @simd for j in CartesianIndices(gridindices)
                i = gridindices[j]
                N = mp.N[j]
                P = value(basis, xₚ[p] - grid.x[i])
                val += N * (P ⋅ grid.poly_coef[i])
            end
            vals[p] = val
        end
    end

    vals
end
