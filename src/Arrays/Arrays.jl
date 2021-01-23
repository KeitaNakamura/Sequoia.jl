module Arrays

using SparseArrays
import SparseArrays: sparse, sparse!

using Base: @_propagate_inbounds_meta

export
# FillArray
    FillArray,
    Ones,
    Zeros,
# ScalarMatrix
    ScalarMatrix,
# SparseMatrixCOO
    SparseMatrixCOO,
    SparseMatrixCSC,
    sparse,
    sparse!,
# List
    List,
    ListGroup

include("FillArray.jl")
include("ScalarMatrix.jl")
include("SparseMatrixCOO.jl")
include("List.jl")

end
