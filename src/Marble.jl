module Marble

using Base: RefValue, @_inline_meta, @_propagate_inbounds_meta, @pure
using Base.Broadcast: Broadcasted, ArrayStyle, broadcasted

using Reexport
@reexport using Tensorial
@reexport using WriteVTK
using StaticArrays, StructArrays

# reexport from StructArrays
export LazyRow, LazyRows

const BLOCK_UNIT = unsigned(3) # 2^3

export
# dot macros
    @dot_threads,
    @dot_lazy,
# coordinate system
    CoordinateSystem,
    PlaneStrain,
    Axisymmetric,
# grid
    Grid,
    gridsteps,
    gridaxes,
    gridorigin,
    gridbounds,
    generate_gridstate,
    generate_pointstate,
# interpolations
    update!,
    gridindices,
    Interpolation,
    BSpline,
    LinearBSpline,
    QuadraticBSpline,
    CubicBSpline,
    GIMP,
    LinearWLS,
    BilinearWLS,
    KernelCorrection,
    MPValues,
# MPSpace
    MPSpace,
    point_to_grid!,
    grid_to_point!,
    grid_to_point,
    update_sparsity_pattern!,
# Transfer
    Transfer,
    DefaultTransfer,
    TransferFLIP,
    TransferPIC,
    TransferTaylorFLIP,
    TransferTaylorPIC,
    TransferAffinePIC,
# Frictional contact
    CoulombFriction,
    contacted,
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


include("misc.jl")
include("utils.jl")
include("dotmacros.jl")
include("sparray.jl")

# core
include("grid.jl")
include("Interpolations/mpvalues.jl")
include("Interpolations/bspline.jl")
include("Interpolations/gimp.jl")
include("Interpolations/polybasis.jl")
include("Interpolations/wls.jl")
include("Interpolations/kenelcorrection.jl")
include("mpspace.jl")

include("states.jl")
include("transfer.jl")
include("contact.jl")

# io
include("logger.jl")
include("vtk.jl")

end # module