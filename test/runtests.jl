using Marble
using Test
using Random, StableRNGs

include("sparray.jl")
include("lattice.jl")
include("particles.jl")
include("interpolations.jl")
include("blockspace.jl")
include("transfer.jl")

const RUN_TESTS = true
@testset "Examples" begin
    cd(tempdir()) do
        include(joinpath(@__DIR__, "../docs/literate/simulations/sand_column_collapse.jl"))
        include(joinpath(@__DIR__, "../docs/literate/simulations/dam_break.jl"))
        include(joinpath(@__DIR__, "../docs/literate/simulations/axial_vibration_of_bar.jl"))
        include(joinpath(@__DIR__, "../docs/literate/simulations/contacting_grains.jl"))
        include(joinpath(@__DIR__, "../docs/literate/simulations/hyperelastic_material.jl"))
        include(joinpath(@__DIR__, "../docs/literate/simulations/elastic_rings.jl"))
    end
end
