########
# Grid #
########

const Grid{N, T, NT <: NamedTuple{<: Any, <: Tuple{AbstractMesh, Vararg{AbstractArray}}}, I} = StructArray{T, N, NT, I}

get_mesh(grid::Grid) = getx(grid)
spacing(grid::Grid) = spacing(get_mesh(grid))
spacing_inv(grid::Grid) = spacing_inv(get_mesh(grid))

##########
# SpGrid #
##########

const SpGrid{N, T, NT <: NamedTuple{<: Any, <: Tuple{AbstractMesh, SpArray, Vararg{SpArray}}}, I} = StructArray{T, N, NT, I}

function check_gridproperty(::Type{GridProp}, ::Type{Vec{dim, T}}) where {GridProp, dim, T}
    V = fieldtype(GridProp, 1)
    if V !== Vec{dim,T}
        error("generate_grid: the first property of grid must be `Vec{$dim, $T}` for given mesh, got $V")
    end
    if !(isbitstype(GridProp))
        error("generate_grid: the property type of grid must be `isbitstype` type")
    end
end

"""
    generate_grid([ArrayType], GridProp, mesh)

Generate background grid with type `GridProp`.
This returns `StructArray` ([StructArrays.jl](https://github.com/JuliaArrays/StructArrays.jl)).
The first field of `GridProp` is used to store `mesh` which requires type `Vec{dim, T}`.
`ArrayType` can be chosen from `Array` and `SpArray`.

# Examples
```jldoctest
julia> struct GridProp{dim, T}
           x  :: Vec{dim, T}
           m  :: Float64
           mv :: Vec{dim, T}
           f  :: Vec{dim, T}
           v  :: Vec{dim, T}
           vⁿ :: Vec{dim, T}
       end

julia> grid = generate_grid(GridProp{2, Float64}, CartesianMesh(0.5, (0,3), (0,2)));

julia> grid[1]
GridProp{2, Float64}([0.0, 0.0], 0.0, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

julia> grid.x
7×5 CartesianMesh{2, Float64, Vector{Float64}}:
 [0.0, 0.0]  [0.0, 0.5]  [0.0, 1.0]  [0.0, 1.5]  [0.0, 2.0]
 [0.5, 0.0]  [0.5, 0.5]  [0.5, 1.0]  [0.5, 1.5]  [0.5, 2.0]
 [1.0, 0.0]  [1.0, 0.5]  [1.0, 1.0]  [1.0, 1.5]  [1.0, 2.0]
 [1.5, 0.0]  [1.5, 0.5]  [1.5, 1.0]  [1.5, 1.5]  [1.5, 2.0]
 [2.0, 0.0]  [2.0, 0.5]  [2.0, 1.0]  [2.0, 1.5]  [2.0, 2.0]
 [2.5, 0.0]  [2.5, 0.5]  [2.5, 1.0]  [2.5, 1.5]  [2.5, 2.0]
 [3.0, 0.0]  [3.0, 0.5]  [3.0, 1.0]  [3.0, 1.5]  [3.0, 2.0]

julia> grid.v
7×5 Matrix{Vec{2, Float64}}:
 [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]
 [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]
 [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]
 [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]
 [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]
 [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]
 [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]  [0.0, 0.0]
```
"""
function generate_grid(::Type{GridProp}, mesh::AbstractMesh) where {GridProp}
    generate_grid(Array, GridProp, mesh)
end

@generated function generate_grid(::Type{Array}, ::Type{GridProp}, mesh::AbstractMesh) where {GridProp}
    exps = [:(Array{$T}(undef, size(mesh))) for T in fieldtypes(GridProp)[2:end]]
    quote
        check_gridproperty(GridProp, eltype(mesh))
        fillzero!(StructArray{GridProp}(tuple(mesh, $(exps...))))
    end
end

# SpArray is designed for Cartesian mesh
@generated function generate_grid(::Type{SpArray}, ::Type{GridProp}, mesh::CartesianMesh) where {GridProp}
    exps = [:(SpArray{$T}(spinds)) for T in fieldtypes(GridProp)[2:end]]
    quote
        check_gridproperty(GridProp, eltype(mesh))
        spinds = SpIndices(size(mesh))
        StructArray{GridProp}(tuple(mesh, $(exps...)))
    end
end

get_spinds(A::SpGrid) = get_spinds(getproperty(A, 2))

function update_block_sparsity!(A::SpGrid, blkspy)
    n = update_block_sparsity!(get_spinds(A), blkspy)
    StructArrays.foreachfield(a->resize_data!(a,n), A)
    A
end

@inline isactive(A::SpGrid, I...) = (@_propagate_inbounds_meta; isactive(get_spinds(A), I...))

Base.show(io::IO, mime::MIME"text/plain", x::SpGrid) = show(io, mime, ShowSpArray(x))
Base.show(io::IO, x::SpGrid) = show(io, ShowSpArray(x))
