struct SpPattern{dim} <: AbstractArray{Bool, dim}
    indices::Array{Int, dim}
end

SpPattern(dims::Tuple{Vararg{Int}}) = SpPattern(fill(-1, dims))
SpPattern(dims::Int...) = SpPattern(dims)

Base.size(sppat::SpPattern) = size(sppat.indices)
Base.IndexStyle(::Type{<: SpPattern}) = IndexLinear()

@inline get_spindices(x::SpPattern) = x.indices
@inline Base.getindex(sppat::SpPattern, i::Int) = (@_propagate_inbounds_meta; sppat.indices[i] !== -1)

function update_sparsity_pattern!(sppat::SpPattern, mask::AbstractArray{Bool})
    @assert size(sppat) == size(mask)
    inds = get_spindices(sppat)
    count = 0
    @inbounds for i in eachindex(sppat, mask)
        inds[i] = (mask[i] ? count += 1 : -1)
    end
    count
end


"""
    SpArray{T}(dims...)

`SpArray` is a kind of sparse array, but it is not allowed to freely change the value like `Array`.
For example, trying to `setindex!` doesn't change anything without any errors as

```jldoctest sparray
julia> A = Marble.SpArray{Float64}(5,5)
5×5 Marble.SpArray{Float64, 2}:
 ⋅  ⋅  ⋅  ⋅  ⋅
 ⋅  ⋅  ⋅  ⋅  ⋅
 ⋅  ⋅  ⋅  ⋅  ⋅
 ⋅  ⋅  ⋅  ⋅  ⋅
 ⋅  ⋅  ⋅  ⋅  ⋅

julia> A[1,1]
0.0

julia> A[1,1] = 2
2

julia> A[1,1]
0.0
```

This is because the index `(1,1)` is not activated yet.
To activate the index, update sparsity pattern by `update_sparsity_pattern!(A, sppat)`.

```jl sparray
julia> sppat = falses(5,5); sppat[1,1] = true; sppat
5×5 BitMatrix:
 1  0  0  0  0
 0  0  0  0  0
 0  0  0  0  0
 0  0  0  0  0
 0  0  0  0  0

julia> update_sparsity_pattern!(A, sppat)
5×5 Marble.SpArray{Float64, 2}:
 2.17321e-314  ⋅  ⋅  ⋅  ⋅
  ⋅            ⋅  ⋅  ⋅  ⋅
  ⋅            ⋅  ⋅  ⋅  ⋅
  ⋅            ⋅  ⋅  ⋅  ⋅
  ⋅            ⋅  ⋅  ⋅  ⋅

julia> A[1,1] = 2; A[1,1]
2.0
```
"""
struct SpArray{T, dim} <: AbstractArray{T, dim}
    data::Vector{T}
    sppat::SpPattern{dim}
    shared_sppat::Bool
end

function SpArray{T}(dims::Tuple{Vararg{Int}}) where {T}
    data = Vector{T}(undef, 0)
    sppat = SpPattern(dims)
    SpArray(data, sppat, false)
end
SpArray{T}(dims::Int...) where {T} = SpArray{T}(dims)

function SpArray{T}(sppat::SpPattern) where {T}
    data = Vector{T}(undef, 0)
    SpArray(data, sppat, true)
end

Base.IndexStyle(::Type{<: SpArray}) = IndexLinear()
Base.size(A::SpArray) = size(A.sppat)

nonzeros(A::SpArray) = A.data
get_sppat(A::SpArray) = A.sppat

# return zero if the index is not active
@inline function Base.getindex(A::SpArray, i::Int)
    @boundscheck checkbounds(A, i)
    sppat = get_sppat(A)
    @inbounds begin
        index = get_spindices(sppat)[i]
        index !== -1 ? nonzeros(A)[index] : zero_recursive(eltype(A))
    end
end

# do nothing if the index is not active (don't throw error!!)
@inline function Base.setindex!(A::SpArray, v, i::Int)
    @boundscheck checkbounds(A, i)
    sppat = get_sppat(A)
    @inbounds begin
        index = get_spindices(sppat)[i]
        index === -1 && return A
        nonzeros(A)[index] = v
    end
    A
end

struct NonzeroIndex{dim}
    parent::CartesianIndex{dim}
    i::Int
end
@inline function Base.getindex(A::SpArray, i::NonzeroIndex)
    @boundscheck checkbounds(nonzeros(A), i.i)
    @inbounds nonzeros(A)[i.i]
end
@inline function Base.setindex!(A::SpArray, v, i::NonzeroIndex)
    @boundscheck checkbounds(nonzeros(A), i.i)
    @inbounds nonzeros(A)[i.i] = v
    A
end
@inline function Base.getindex(A::AbstractArray, i::NonzeroIndex)
    @boundscheck checkbounds(A, i.parent)
    @inbounds A[i.parent]
end
@inline function Base.setindex!(A::AbstractArray, v, i::NonzeroIndex)
    @boundscheck checkbounds(A, i.parent)
    @inbounds A[i.parent] = v
    A
end

fillzero!(A::SpArray) = (fillzero!(A.data); A)

function update_sparsity_pattern!(A::SpArray, sppat::AbstractArray{Bool})
    A.shared_sppat && error("SpArray: `update_sparsity_pattern!` should be done in `update!` for `MPSpace`. Don't call this manually.")
    @assert size(A) == size(sppat)
    n = update_sparsity_pattern!(get_sppat(A), sppat)
    resize!(nonzeros(A), n)
    A
end

#############
# Broadcast #
#############

Broadcast.BroadcastStyle(::Type{<: SpArray}) = ArrayStyle{SpArray}()

function Base.similar(bc::Broadcasted{ArrayStyle{SpArray}}, ::Type{ElType}) where {ElType}
    N = ndims(bc)
    bc′ = convert(Broadcasted{DefaultArrayStyle{N}}, bc)
    similar(bc′, ElType)
end

function Base.copyto!(dest::SpArray, bc::Broadcasted{ArrayStyle{SpArray}})
    axes(dest) == axes(bc) || throwdm(axes(dest), axes(bc))
    bcf = Broadcast.flatten(bc)
    !identical_sppat(dest, bcf.args...) &&
        error("SpArray: broadcast along with different `SpPattern`s is not supported")
    Base.copyto!(_nonzeros(dest), _nonzeros(bc))
    dest
end
@inline _nonzeros(bc::Broadcasted{ArrayStyle{SpArray}}) = Broadcast.broadcasted(bc.f, map(_nonzeros, bc.args)...)
@inline _nonzeros(x::SpArray) = nonzeros(x)
@inline _nonzeros(x::Any) = x

# helpers for copyto!
# all abstract arrays except SpArray and Tensor are not allowed in broadcasting
_ok(::Type{<: AbstractArray}) = false
_ok(::Type{<: SpArray})       = true
_ok(::Type{<: Tensor})        = true
_ok(::Type{<: Any})           = true
@generated function identical_sppat(args...)
    all(_ok, args) || return :(false)
    exps = [:(args[$i].sppat) for i in 1:length(args) if args[i] <: SpArray]
    n = length(exps)
    quote
        sppats = tuple($(exps...))
        @nall $n i -> sppats[1] === sppats[i]
    end
end

###############
# Custom show #
###############

struct CDot end
Base.show(io::IO, x::CDot) = print(io, "⋅")

struct ShowSpArray{T, N, A <: AbstractArray{T, N}} <: AbstractArray{T, N}
    parent::A
end
Base.size(x::ShowSpArray) = size(x.parent)
Base.axes(x::ShowSpArray) = axes(x.parent)
@inline function Base.getindex(x::ShowSpArray, i::Int...)
    @_propagate_inbounds_meta
    p = x.parent
    get_sppat(p)[i...] ? maybecustomshow(p[i...]) : CDot()
end
maybecustomshow(x) = x
maybecustomshow(x::SpArray) = ShowSpArray(x)

Base.summary(io::IO, x::ShowSpArray) = summary(io, x.parent)
Base.show(io::IO, mime::MIME"text/plain", x::SpArray) = show(io, mime, ShowSpArray(x))
Base.show(io::IO, x::SpArray) = show(io, ShowSpArray(x))
