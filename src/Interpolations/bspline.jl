struct BSpline{order} <: Kernel
    BSpline{order}() where {order} = new{order::Int}()
end

"""
    BSpline{1}()
    LinearBSpline()

Linear B-spline kernel.
"""
const LinearBSpline = BSpline{1}

"""
    BSpline{2}()
    QuadraticBSpline()

Quadratic B-spline kernel.
The peaks of this funciton are centered on the grid nodes [^Steffen].

[^Steffen]: [Steffen, M., Kirby, R. M., & Berzins, M. (2008). Analysis and reduction of quadrature errors in the material point method (MPM). *International journal for numerical methods in engineering*, 76(6), 922-948.](https://doi.org/10.1002/nme.2360)
"""
const QuadraticBSpline = BSpline{2}

"""
    BSpline{3}()
    CubicBSpline()

Cubic B-spline kernel.
The peaks of this funciton are centered on the grid nodes [^Steffen].

[^Steffen]: [Steffen, M., Kirby, R. M., & Berzins, M. (2008). Analysis and reduction of quadrature errors in the material point method (MPM). *International journal for numerical methods in engineering*, 76(6), 922-948.](https://doi.org/10.1002/nme.2360)
"""
const CubicBSpline = BSpline{3}

gridspan(::BSpline{1}) = 2
gridspan(::BSpline{2}) = 3
gridspan(::BSpline{3}) = 4

@inline function neighboringnodes(spline::BSpline, pt, mesh::CartesianMesh{dim}) where {dim}
    x = getx(pt)
    ξ = Tuple(normalize(x, mesh))
    dims = size(mesh)
    isinside(ξ, dims) || return EmptyCartesianIndices(Val(dim))
    offset = _neighboringnodes_offset(spline)
    r = gridspan(spline) - 1
    start = @. unsafe_trunc(Int, floor(ξ - offset)) + 1
    stop = @. start + r
    imin = Tuple(@. max(start, 1))
    imax = Tuple(@. min(stop, dims))
    CartesianIndices(UnitRange.(imin, imax))
end
@inline _neighboringnodes_offset(::BSpline{1}) = 0.0
@inline _neighboringnodes_offset(::BSpline{2}) = 0.5
@inline _neighboringnodes_offset(::BSpline{3}) = 1.0

# simple B-spline calculations
function value(::BSpline{1}, ξ::Real)
    ξ = abs(ξ)
    ξ < 1 ? 1 - ξ : zero(ξ)
end
function value(::BSpline{2}, ξ::Real)
    ξ = abs(ξ)
    ξ < 0.5 ? (3 - 4ξ^2) / 4 :
    ξ < 1.5 ? (3 - 2ξ)^2 / 8 : zero(ξ)
end
function value(::BSpline{3}, ξ::Real)
    ξ = abs(ξ)
    ξ < 1 ? (3ξ^3 - 6ξ^2 + 4) / 6 :
    ξ < 2 ? (2 - ξ)^3 / 6         : zero(ξ)
end
@generated function value(spline::BSpline, ξ::Vec{dim}) where {dim}
    quote
        @_inline_meta
        prod(@ntuple $dim i -> value(spline, ξ[i]))
    end
end
@inline function value(spline::BSpline, pt, mesh::CartesianMesh, i)
    @_propagate_inbounds_meta
    xₚ = getx(pt)
    xᵢ = mesh[i]
    h⁻¹ = spacing_inv(mesh)
    ξ = (xₚ - xᵢ) * h⁻¹
    value(spline, ξ)
end

# Steffen, M., Kirby, R. M., & Berzins, M. (2008).
# Analysis and reduction of quadrature errors in the material point method (MPM).
# International journal for numerical methods in engineering, 76(6), 922-948.
function value(spline::BSpline{1}, ξ::Real, pos::Int)::typeof(ξ)
    value(spline, ξ)
end
function value(spline::BSpline{2}, ξ::Real, pos::Int)::typeof(ξ)
    if pos == 0
        ξ = abs(ξ)
        ξ < 0.5 ? (3 - 4ξ^2) / 3 :
        ξ < 1.5 ? (3 - 2ξ)^2 / 6 : zero(ξ)
    elseif abs(pos) == 1
        ξ = sign(pos) * ξ
        ξ < -1   ? zero(ξ)                 :
        ξ < -0.5 ? 4(1 + ξ)^2 / 3          :
        ξ <  0.5 ? -(28ξ^2 - 4ξ - 17) / 24 :
        ξ <  1.5 ? (3 - 2ξ)^2 / 8          : zero(ξ)
    else
        value(spline, ξ)
    end
end
function value(spline::BSpline{3}, ξ::Real, pos::Int)::typeof(ξ)
    if pos == 0
        ξ = abs(ξ)
        ξ < 1 ? (3ξ^3 - 6ξ^2 + 4) / 4 :
        ξ < 2 ? (2 - ξ)^3 / 4         : zero(ξ)
    elseif abs(pos) == 1
        ξ = sign(pos) * ξ
        ξ < -1 ? zero(ξ)                      :
        ξ <  0 ? (1 + ξ)^2 * (7 - 11ξ) / 12   :
        ξ <  1 ? (7ξ^3 - 15ξ^2 + 3ξ + 7) / 12 :
        ξ <  2 ? (2 - ξ)^3 / 6                : zero(ξ)
    else
        value(spline, ξ)
    end
end
@generated function value(spline::BSpline, ξ::Vec{dim}, pos::Vec{dim}) where {dim}
    quote
        @_inline_meta
        prod(@ntuple $dim i -> value(spline, ξ[i], pos[i]))
    end
end
@inline function value(spline::BSpline, xₚ::Vec, mesh::CartesianMesh, i::CartesianIndex, ::Symbol) # last argument is pseudo argument `:steffen`
    @_propagate_inbounds_meta
    xᵢ = mesh[i]
    h⁻¹ = spacing_inv(mesh)
    ξ = (xₚ - xᵢ) * h⁻¹
    value(spline, ξ, node_position(mesh, i))
end

@inline function node_position(ax::AbstractVector, i::Int)
    left = i - firstindex(ax)
    right = lastindex(ax) - i
    ifelse(left < right, left, -right)
end
node_position(mesh::CartesianMesh, index::CartesianIndex) = Vec(map(node_position, get_axes(mesh), Tuple(index)))


@inline fract(x) = x - floor(x)
# Fast calculations for value, gradient and hessian
# `x` must be normalized by `h`
@inline Base.values(spline::BSpline, x::Real) = values(nothing, spline, x)
@inline function Base.values(diff, ::BSpline{1}, x::Real)
    T = typeof(x)
    V = NTuple{2, T}
    ξ = fract(x)
    vals = V((1-ξ, ξ))
    if diff === gradient || diff === hessian
        vals = (vals, V((-1, 1)))
    end
    if diff === hessian
        vals = (vals..., V((0, 0)))
    end
    vals
end
@inline function Base.values(diff, ::BSpline{2}, x::Real)
    T = typeof(x)
    V = NTuple{3, T}
    x′ = fract(x - T(0.5))
    ξ = @. x′ - $V((-0.5,0.5,1.5))
    vals = @. $V((0.5,-1.0,0.5))*ξ^2 + $V((-1.5,0.0,1.5))*ξ + $V((1.125,0.75,1.125))
    if diff === gradient || diff === hessian
        vals = (vals, @.($V((1.0,-2.0,1.0))*ξ + $V((-1.5,0.0,1.5))))
    end
    if diff === hessian
        vals = (vals..., @.($V((1.0,-2.0,1.0))))
    end
    vals
end
@inline function Base.values(diff, ::BSpline{3}, x::Real)
    T = typeof(x)
    V = NTuple{4, T}
    x′ = fract(x)
    ξ = @. x′ - $V((-1,0,1,2))
    ξ² = @. ξ * ξ
    ξ³ = @. ξ² * ξ
    vals = @. $V((-1/6,0.5,-0.5,1/6))*ξ³ + $V((1,-1,-1,1))*ξ² + $V((-2,0,0,2))*ξ + $V((4/3,2/3,2/3,4/3))
    if diff === gradient || diff === hessian
        vals = (vals, @.($V((-0.5,1.5,-1.5,0.5))*ξ² + $V((2,-2,-2,2))*ξ + $V((-2,0,0,2))))
    end
    if diff === hessian
        vals = (vals..., @.($V((-1.0,3.0,-3.0,1.0))*ξ + $V((2,-2,-2,2))))
    end
    vals
end

@generated function Base.values(spline::BSpline, x::Vec{dim}) where {dim}
    quote
        @_inline_meta
        tuple_otimes(@ntuple $dim d -> values(spline, x[d]))
    end
end
@generated function Base.values(::typeof(gradient), spline::BSpline, x::Vec{dim}) where {dim}
    quote
        @_inline_meta
        @nexprs $dim d -> (x_d, ∇x_d) = values(gradient, spline, x[d])
        Ns = @ntuple $dim d -> x_d
        ∇Ns = @ntuple $dim i -> (@ntuple $dim k -> k==i ? ∇x_k : x_k)
        tuple_otimes(Ns), map(Vec, map(tuple_otimes, ∇Ns)...)
    end
end
@generated function Base.values(::typeof(hessian), spline::BSpline, x::Vec{dim}) where {dim}
    ∇∇Ns = Expr(:tuple, map(1:dim) do j
               Expr(:tuple, map(j:dim) do i
                   :(@ntuple $dim k -> k==$j ? (k==$i ? ∇∇x_k : ∇x_k) : ∇Ns[$i][k])
               end...)
           end...)
    quote
        @_inline_meta
        @nexprs $dim d -> (x_d, ∇x_d, ∇∇x_d) = values(hessian, spline, x[d])
        Ns = @ntuple $dim d -> x_d
        ∇Ns = @ntuple $dim i -> (@ntuple $dim k -> k==i ? ∇x_k : x_k)
        # ∇∇Ns = @ntuple $dim j -> (@ntuple $dim i -> (@ntuple $dim k -> k==j ? (k==i ? ∇∇x_k : ∇x_k) : ∇Ns[i][k]))
        tuple_otimes(Ns), map(Vec, map(tuple_otimes, ∇Ns)...), map(SymmetricSecondOrderTensor{dim}, map(tuple_otimes, flatten_tuple($∇∇Ns))...)
    end
end
@inline tuple_otimes(x::Tuple) = SArray(otimes(map(Vec, x)...))

@inline function Base.values(spline::BSpline, x::Vec, mesh::CartesianMesh)
    h⁻¹ = spacing_inv(mesh)
    values(spline, (x - first(mesh)) * h⁻¹)
end
@inline function Base.values(::typeof(gradient), spline::BSpline, x::Vec, mesh::CartesianMesh)
    xmin = first(mesh)
    h⁻¹ = spacing_inv(mesh)
    N, ∇N = values(gradient, spline, (x-xmin)*h⁻¹)
    (N, ∇N*h⁻¹)
end
@inline function Base.values(::typeof(hessian), spline::BSpline, x::Vec, mesh::CartesianMesh)
    xmin = first(mesh)
    h⁻¹ = spacing_inv(mesh)
    N, ∇N, ∇∇N = values(hessian, spline, (x-xmin)*h⁻¹, gradient)
    (N, ∇N*h⁻¹, ∇∇N*h⁻¹*h⁻¹)
end

function update_property!(mp::MPValue{<: BSpline}, pt, mesh::CartesianMesh)
    indices = neighboringnodes(mp)
    if isnearbounds(mp)
        @inbounds for ip in eachindex(indices)
            i = indices[ip]
            mp.∇N[ip], mp.N[ip] = gradient(x->value(interpolation(mp),x,mesh,i,:steffen), getx(pt), :all)
        end
    else
        map(copyto!, (mp.N, mp.∇N), values(gradient, interpolation(mp), getx(pt), mesh))
    end
end
