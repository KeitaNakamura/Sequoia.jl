struct GIMP <: Kernel end

@pure num_nodes(f::GIMP, ::Val{dim}) where {dim} = prod(nfill(3, Val(dim)))

@inline function nodeindices(f::GIMP, grid::Grid, xp::Vec, rp::Vec)
    dx⁻¹ = gridsteps_inv(grid)
    nodeindices(grid, xp, 1 .+ rp.*dx⁻¹)
end
@inline nodeindices(f::GIMP, grid::Grid, pt) = nodeindices(f, grid, pt.x, pt.r)

# simple GIMP calculation
# See Eq.(40) in
# Bardenhagen, S. G., & Kober, E. M. (2004).
# The generalized interpolation material point method.
# Computer Modeling in Engineering and Sciences, 5(6), 477-496.
# boundary treatment is ignored
function value(::GIMP, ξ::Real, l::Real) # `l` is normalized radius
    ξ = abs(ξ)
    ξ < l   ? 1 - (ξ^2 + l^2) / 2l :
    ξ < 1-l ? 1 - ξ                :
    ξ < 1+l ? (1+l-ξ)^2 / 4l       : zero(ξ)
end
@inline value(f::GIMP, ξ::Vec, l::Vec) = prod(map_tuple(value, f, Tuple(ξ), Tuple(l)))
# used in `WLS`
function value(f::GIMP, grid::Grid, I::Index, xp::Vec, rp::Vec)
    @_inline_propagate_inbounds_meta
    xi = grid[I]
    dx⁻¹ = gridsteps_inv(grid)
    ξ = (xp - xi) .* dx⁻¹
    value(f, ξ, rp.*dx⁻¹)
end
@inline value(f::GIMP, grid::Grid, I::Index, pt) = value(f, grid, I, pt.x, pt.r)
# used in `KernelCorrection`
function value_gradient(f::GIMP, grid::Grid, I::Index, xp::Vec, rp::Vec)
    @_inline_propagate_inbounds_meta
    xi = grid[I]
    dx⁻¹ = gridsteps_inv(grid)
    ξ = (xp - xi) .* dx⁻¹
    ∇w, w = gradient(ξ -> value(f, ξ, rp.*dx⁻¹), ξ, :all)
    w, ∇w.*dx⁻¹
end
@inline value_gradient(f::GIMP, grid::Grid, I::Index, pt) = value_gradient(f, grid, I, pt.x, pt.r)

# used in `WLS`
# `x` and `l` must be normalized by `dx`
@inline function Base.values(::GIMP, x::T, l::T) where {T <: Real}
    V = Vec{3, T}
    x′ = fract(x - T(0.5))
    ξ = x′ .- V(-0.5, 0.5, 1.5)
    map_tuple(value, GIMP(), Tuple(ξ), Tuple(l))
end
@inline Base.values(f::GIMP, x::Vec, l::Vec) = Tuple(otimes(map_tuple(values, f, Tuple(x), Tuple(l))...))
function Base.values(f::GIMP, grid::Grid, xp::Vec, lp::Vec)
    dx⁻¹ = gridsteps_inv(grid)
    values(f, xp.*dx⁻¹, lp.*dx⁻¹)
end
@inline Base.values(f::GIMP, grid::Grid, pt) = values(f, grid, pt.x, pt.r)

# used in `KernelCorrection`
# `x` and `l` must be normalized by `dx`
_gradient_GIMP(x, l) = gradient(x -> value(GIMP(), x, l), x, :all)
function _values_gradients(::GIMP, x::T, l::T) where {T <: Real}
    V = Vec{3, T}
    x′ = fract(x - T(0.5))
    ξ = x′ .- V(-0.5, 0.5, 1.5)
    vals_grads = map_tuple(_gradient_GIMP, Tuple(ξ), l)
    vals  = map_tuple(getindex, vals_grads, 2)
    grads = map_tuple(getindex, vals_grads, 1)
    Vec(vals), Vec(grads)
end
@generated function values_gradients(::GIMP, x::Vec{dim}, l::Vec{dim}) where {dim}
    exps = map(1:dim) do i
        x = [d == i ? :(grads[$d]) : :(vals[$d]) for d in 1:dim]
        :(Tuple(otimes($(x...))))
    end
    quote
        @_inline_meta
        vals_grads = map_tuple(_values_gradients, GIMP(), Tuple(x), Tuple(l))
        vals  = map_tuple(getindex, vals_grads, 1)
        grads = map_tuple(getindex, vals_grads, 2)
        Tuple(otimes(vals...)), map_tuple(Vec, $(exps...))
    end
end
function values_gradients(f::GIMP, grid::Grid, xp::Vec, lp::Vec)
    dx⁻¹ = gridsteps_inv(grid)
    wᵢ, ∇wᵢ = values_gradients(f, xp.*dx⁻¹, lp.*dx⁻¹)
    wᵢ, broadcast(.*, ∇wᵢ, Ref(dx⁻¹))
end
@inline values_gradients(f::GIMP, grid::Grid, pt) = values_gradients(f, grid, pt.x, pt.r)


mutable struct GIMPValue{dim, T, L} <: MPValue{dim, T}
    F::GIMP
    N::MVector{L, T}
    ∇N::MVector{L, Vec{dim, T}}
    # necessary in MPValue
    xp::Vec{dim, T}
    nodeindices::MVector{L, Index{dim}}
    len::Int
end

function MPValue{dim, T}(F::GIMP) where {dim, T}
    L = num_nodes(F, Val(dim))
    N = MVector{L, T}(undef)
    ∇N = MVector{L, Vec{dim, T}}(undef)
    xp = zero(Vec{dim, T})
    nodeindices = MVector{L, Index{dim}}(undef)
    GIMPValue(F, N, ∇N, xp, nodeindices, 0)
end

get_kernel(mp::GIMPValue) = mp.F
@inline function mpvalue(mp::GIMPValue, i::Int)
    @boundscheck @assert 1 ≤ i ≤ num_nodes(mp)
    (; N=mp.N[i], ∇N=mp.∇N[i], xp=mp.xp)
end

function update_kernels!(mp::GIMPValue, grid::Grid, pt)
    # reset
    fillzero!(mp.N)
    fillzero!(mp.∇N)

    # update
    F = get_kernel(mp)
    @inbounds @simd for i in 1:num_nodes(mp)
        I = nodeindex(mp, i)
        mp.N[i], mp.∇N[i] = value_gradient(F, grid, I, pt)
    end
    mp
end
