using Documenter
using Sequoia

ENV["PLOTS_TEST"] = "true"
ENV["GKSwstype"] = "100"

# Setup for doctests in docstrings
DocMeta.setdocmeta!(Sequoia, :DocTestSetup, :(using Sequoia); recursive=true)

# generate documentation by Literate.jl
include("literate.jl")

makedocs(;
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    modules = [Sequoia],
    sitename = "Sequoia.jl",
    pages=[
        "Home" => "index.md",
        "getting_started.md",
        "Examples" => [
            "examples/elastic_impact.md",
            "examples/tlmpm_vortex.md",
            "examples/implicit_jacobian_free.md",
            "examples/implicit_jacobian_based.md",
            # "examples/dam_break.md",
            "examples/rigid_body_contact.md",
        ],
    ],
    doctest = true, # :fix
    warnonly = [:missing_docs],
)

deploydocs(
    repo = "github.com/KeitaNakamura/Sequoia.jl.git",
    devbranch = "main",
)
