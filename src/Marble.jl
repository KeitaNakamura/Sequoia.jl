module Marble

using Base: RefValue, @_inline_meta, @_propagate_inbounds_meta, @pure
using Base.Broadcast: Broadcasted, ArrayStyle
using Base.Cartesian: @ntuple, @nall, @nexprs

using Reexport
@reexport using Tensorial
@reexport using WriteVTK
using StructArrays

import SIMD
const SVec = SIMD.Vec
const SIMDTypes = Union{Float16, Float32, Float64}

# reexport from StructArrays
export LazyRow, LazyRows

const BLOCK_UNIT = unsigned(3) # 2^3

export
# coordinate system
    CoordinateSystem,
    PlaneStrain,
    Axisymmetric,
# grid
    Grid,
    gridsteps,
    gridaxes,
    gridsystem,
    gridbounds,
    neighbornodes,
    generate_gridstate,
    generate_pointstate,
# interpolations
    update!,
    num_nodes,
    Interpolation,
    BSpline,
    LinearBSpline,
    QuadraticBSpline,
    CubicBSpline,
    GIMP,
    LinearWLS,
    KernelCorrection,
    MPValue,
# MPSpace
    MPSpace,
    get_mpvalue,
    get_nodeindices,
    point_to_grid!,
    grid_to_point!,
    update_sparsity_pattern!,
# Transfer
    Transfer,
    FLIP,
    PIC,
    TFLIP,
    TPIC,
    AFLIP,
    APIC,
# Logger
    Logger,
    isfinised,
    islogpoint,
    logindex,
# VTK
    openvtk,
    openvtm,
    openpvd,
    closevtk,
    closevtm,
    closepvd


include("utils.jl")
include("sparray.jl")

# core
include("grid.jl")
include("Interpolations/mpvalue.jl")
include("Interpolations/bspline.jl")
include("Interpolations/gimp.jl")
include("Interpolations/polybasis.jl")
include("Interpolations/wls.jl")
include("Interpolations/kernelcorrection.jl")
include("mpspace.jl")

include("states.jl")
include("transfer.jl")

# io
include("logger.jl")
include("vtk.jl")

end # module
