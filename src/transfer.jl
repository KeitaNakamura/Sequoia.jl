abstract type TransferAlgorithm end
struct DefaultTransfer <: TransferAlgorithm end
# classical
struct FLIP  <: TransferAlgorithm end
struct PIC   <: TransferAlgorithm end
# affine transfer
struct AffineTransfer{T <: Union{FLIP, PIC}} <: TransferAlgorithm end
AffineTransfer(t::TransferAlgorithm) = AffineTransfer{typeof(t)}()
const AFLIP = AffineTransfer{FLIP}
const APIC  = AffineTransfer{PIC}
# Taylor transfer
struct TaylorTransfer{T <: Union{FLIP, PIC}} <: TransferAlgorithm end
TaylorTransfer(t::TransferAlgorithm) = TaylorTransfer{typeof(t)}()
const TFLIP = TaylorTransfer{FLIP}
const TPIC  = TaylorTransfer{PIC}

const FLIPGroup = Union{DefaultTransfer, FLIP, AFLIP, TFLIP}
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
    get_sppat(grid) !== get_gridsppat(space) &&
        error("Using different sparsity pattern between `MPSpace` and `Grid`")
end

function check_statenames(part::Tuple{Vararg{Symbol}}, all::Tuple{Vararg{Symbol}})
    isempty(setdiff!(Set(part), Set(all))) || error("unsupported state names, got $part, available names are $all")
end

################
# P2G transfer #
################

function particle_to_grid!(names::Tuple{Vararg{Symbol}}, grid::Grid, particles::Particles, space::MPSpace; alg::TransferAlgorithm = DefaultTransfer(), system::CoordinateSystem = NormalSystem())
    particle_to_grid!(alg, system, Val(names), grid, particles, space)
end

# don't use dispatch and all transfer algorithms are writtein in this function to reduce a lot of deplicated code
function particle_to_grid!(alg::TransferAlgorithm, system::CoordinateSystem, ::Val{names}, grid::Grid, particles::Particles, space::MPSpace{dim, T}) where {names, dim, T}
    check_statenames(names, (:m, :mv, :f))
    check_grid(grid, space)
    check_particles(particles, space)

    itp = get_interpolation(space)
    P = x -> value(get_basis(itp), x)
    parallel_each_particle(space) do p
        @_inline_meta
        @inbounds begin
            mp = values(space, p)

            if :m in names
                mₚ = particles.m[p]
            end

            if :f in names
                Vₚσₚ = particles.V[p] * particles.σ[p]
                if hasproperty(particles, :b)
                    mₚbₚ = particles.m[p] * particles.b[p]
                end
                if system isa Axisymmetric
                    rₚ = particles.x[p][1]
                end
            end

            # grid momentum depends on transfer algorithms
            if :mv in names
                if alg isa DefaultTransfer && itp isa WLS
                    xₚ = particles.x[p]
                    mₚCₚ = particles.m[p] * particles.C[p]
                else
                    mₚvₚ = particles.m[p] * particles.v[p]

                    # additional term from high order approximation
                    if alg isa AffineTransfer
                        xₚ = particles.x[p]
                        Dₚ = zero(Mat{dim, dim, T})
                        for (j, i) in pairs(IndexCartesian(), neighbornodes(space, p))
                            N = mp.N[j]
                            xᵢ = grid.x[i]
                            Dₚ += N*(xᵢ-xₚ)⊗(xᵢ-xₚ)
                        end
                        mₚCₚ = particles.m[p] * particles.B[p] ⋅ inv(Dₚ)
                    elseif alg isa TaylorTransfer
                        xₚ = particles.x[p]
                        mₚ∇vₚ = particles.m[p] * @Tensor(particles.∇v[p][1:dim, 1:dim])
                    end
                end
            end

            for (j, i) in pairs(IndexCartesian(), neighbornodes(space, p))
                N = mp.N[j]
                ∇N = mp.∇N[j]

                if :m in names
                    grid.m[i] += N*mₚ
                end

                if :f in names
                    if system isa Axisymmetric
                        f = -calc_fint(system, N, ∇N, Vₚσₚ, rₚ)
                    else
                        f = -calc_fint(system, ∇N, Vₚσₚ)
                    end
                    if hasproperty(particles, :b)
                        f += N*mₚbₚ
                    end
                    grid.f[i] += f
                end

                # grid momentum depends on transfer algorithms
                if :mv in names
                    xᵢ = grid.x[i]
                    if alg isa DefaultTransfer && itp isa WLS
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
    end

    grid
end

# 1D
@inline calc_fint(::NormalSystem, ∇N::Vec{1}, Vₚσₚ::SymmetricSecondOrderTensor{1}) = σₚ ⋅ ∇N
# plane-strain
@inline calc_fint(::Union{NormalSystem, PlaneStrain}, ∇N::Vec{2}, Vₚσₚ::SymmetricSecondOrderTensor{3}) = @Tensor(Vₚσₚ[1:2,1:2]) ⋅ ∇N
@inline calc_fint(::Union{NormalSystem, PlaneStrain}, ∇N::Vec{2}, Vₚσₚ::SymmetricSecondOrderTensor{2}) = Vₚσₚ ⋅ ∇N
# axisymmetric
@inline calc_fint(::Axisymmetric, N::Real, ∇N::Vec{2}, Vₚσₚ::SymmetricSecondOrderTensor{3}, rₚ::Real) = @Tensor(Vₚσₚ[1:2,1:2])⋅∇N + Vec(1,0)*Vₚσₚ[3,3]*N*rₚ
# 3D
@inline calc_fint(::NormalSystem, ∇N::Vec{3}, Vₚσₚ::SymmetricSecondOrderTensor{3}) = Vₚσₚ ⋅ ∇N

################
# G2P transfer #
################

function grid_to_particle!(names::Tuple{Vararg{Symbol}}, particles::Particles, grid::Grid, space::MPSpace, dt::Real; alg::TransferAlgorithm = DefaultTransfer(), system::CoordinateSystem = NormalSystem())
    grid_to_particle!(alg, system, Val(names), particles, grid, space, dt)
end

function grid_to_particle!(alg::TransferAlgorithm, system::CoordinateSystem, ::Val{names}, particles::Particles, grid::Grid, space::MPSpace{dim}, dt::Real) where {names, dim}
    check_statenames(names, (:v, :∇v, :x))
    check_grid(grid, space)
    check_particles(particles, space)

    @threaded for p in 1:num_particles(space)
        mp = values(space, p)

        # there is no difference along with transfer algorithms for calculating `:∇v` and `:x`
        if :∇v in names
            ∇vₚ = @Tensor zero(eltype(particles.∇v))[1:dim, 1:dim]
            if system isa Axisymmetric
                vₚ = zero(eltype(particles.v))
            end
        end

        if :x in names
            vₚ = zero(eltype(particles.v))
        end

        # particle velocity depends on transfer algorithms
        if :v in names
            if alg isa FLIPGroup
                dvₚ = zero(eltype(particles.v))
            else
                @assert alg isa PICGroup
                vₚ = zero(eltype(particles.v))
            end
            if alg isa AffineTransfer
                # Bₚ is always calculated when `:v` is specified
                xₚ = particles.x[p]
                Bₚ = zero(eltype(particles.B))
            end
        end

        for (j, i) in pairs(IndexCartesian(), neighbornodes(space, p))
            N = mp.N[j]
            ∇N = mp.∇N[j]

            # 100% used
            vᵢ = grid.v[i]

            if :∇v in names
                ∇vₚ += vᵢ ⊗ ∇N
            end

            # use `@isdefined` to avoid complicated check
            # for `:v` in `PIC` is also calculated here
            if @isdefined vₚ
                vₚ += vᵢ * N
            end

            # particle velocity depends on transfer algorithms
            if :v in names
                if alg isa FLIPGroup
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
            T_∇v = eltype(particles.∇v)
            if system isa Axisymmetric
                particles.∇v[p] = calc_∇v(system, T_∇v, ∇vₚ, vₚ[1], particles.x[p][1])
            else
                particles.∇v[p] = calc_∇v(system, T_∇v, ∇vₚ)
            end
        end

        if :x in names
            particles.x[p] += vₚ * dt
        end

        # particle velocity depends on transfer algorithms
        if :v in names
            if alg isa FLIPGroup
                particles.v[p] += dvₚ
            else
                @assert alg isa PICGroup
                particles.v[p] = vₚ
            end
            if alg isa AffineTransfer
                # additional quantity for affine transfers
                # Bₚ is always calculated when `:v` is specified
                particles.B[p] = Bₚ
            end
        end
    end

    particles
end

# special default transfer for `WLS` interpolation
function grid_to_particle!(::DefaultTransfer, system::CoordinateSystem, ::Val{names}, particles::Particles, grid::Grid, space::MPSpace{dim, <: Any, <: WLS}, dt::Real) where {names, dim}
    check_statenames(names, (:v, :∇v, :x))
    check_grid(grid, space)
    check_particles(particles, space)

    itp = get_interpolation(space)
    basis = get_basis(itp)
    P = x -> value(basis, x)
    p0 = value(basis, zero(Vec{dim, Int}))
    ∇p0 = gradient(basis, zero(Vec{dim, Int}))
    @threaded for p in 1:num_particles(space)
        mp = values(space, p)

        xₚ = particles.x[p]
        Cₚ = zero(eltype(particles.C))

        for (j, i) in pairs(IndexCartesian(), neighbornodes(space, p))
            w = mp.w[j]
            Minv = mp.Minv[]
            vᵢ = grid.v[i]
            xᵢ = grid.x[i]
            Cₚ += vᵢ ⊗ (w * Minv ⋅ P(xᵢ - xₚ))
        end

        vₚ = Cₚ ⋅ p0

        if :∇v in names
            ∇vₚ = Cₚ ⋅ ∇p0
            T_∇v = eltype(particles.∇v)
            if system isa Axisymmetric
                particles.∇v[p] = calc_∇v(system, T_∇v, ∇vₚ, vₚ[1], particles.x[p][1])
            else
                particles.∇v[p] = calc_∇v(system, T_∇v, ∇vₚ)
            end
        end

        if :x in names
            particles.x[p] += vₚ * dt
        end

        if :v in names
            particles.v[p] = vₚ
            particles.C[p] = Cₚ # always update when velocity is updated
        end
    end

    particles
end

# 1D
@inline calc_∇v(::NormalSystem, ::Type{<: SecondOrderTensor{1}}, ∇vₚ::SecondOrderTensor{1}) = ∇vₚ
# plane-strain
@inline calc_∇v(::Union{NormalSystem, PlaneStrain}, ::Type{<: SecondOrderTensor{2}}, ∇vₚ::SecondOrderTensor{2}) = ∇vₚ
@inline calc_∇v(::Union{NormalSystem, PlaneStrain}, ::Type{<: SecondOrderTensor{3}}, ∇vₚ::SecondOrderTensor{2}) = Tensorial.resizedim(∇vₚ, Val(3))
# axisymmetric
@inline calc_∇v(::Axisymmetric, ::Type{<: SecondOrderTensor{3}}, ∇vₚ::SecondOrderTensor{2}, v::Real, r::Real) = Tensorial.resizedim(∇v, Val(3)) + @Mat([0 0 0; 0 0 0; 0 0 v/r])
# 3D
@inline calc_∇v(::NormalSystem, ::Type{<: SecondOrderTensor{3}}, ∇vₚ::SecondOrderTensor{3}) = ∇vₚ

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

function smooth_particle_state!(vals::AbstractVector, xₚ::AbstractVector, Vₚ::AbstractVector, grid::Grid, space::MPSpace)
    check_grid(grid, space)
    check_particles(vals, space)
    check_particles(xₚ, space)
    check_particles(Vₚ, space)

    basis = PolynomialBasis{1}()
    fillzero!(grid.poly_coef)
    fillzero!(grid.poly_mat)

    parallel_each_particle(space) do p
        @inbounds begin
            mp = values(space, p)
            for (j, i) in pairs(IndexCartesian(), neighbornodes(space, p))
                N = mp.N[j]
                P = value(basis, xₚ[p] - grid.x[i])
                VP = (N * Vₚ[p]) * P
                grid.poly_coef[i] += VP * vals[p]
                grid.poly_mat[i]  += VP ⊗ P
            end
        end
    end

    @. grid.poly_coef = safe_inv(grid.poly_mat) ⋅ grid.poly_coef

    @threaded for p in 1:num_particles(space)
        val = zero(eltype(vals))
        mp = values(space, p)
        for (j, i) in pairs(IndexCartesian(), neighbornodes(space, p))
            N = mp.N[j]
            P = value(basis, xₚ[p] - grid.x[i])
            val += N * (P ⋅ grid.poly_coef[i])
        end
        vals[p] = val
    end

    vals
end
