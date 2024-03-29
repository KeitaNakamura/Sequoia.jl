const RUN_TESTS = true

@testset "Examples" begin
    @testset "Elastic impact between two rings" begin
        cd(tempdir()) do
            include(joinpath(@__DIR__, "../docs/literate/examples/elastic_impact.jl"))
        end
    end
    @testset "Vortex by Total Lagrangian MPM" begin
        cd(tempdir()) do
            include(joinpath(@__DIR__, "../docs/literate/examples/tlmpm_vortex.jl"))
        end
    end
end
