using Pkg
Pkg.develop(PackageSpec(path = dirname(@__DIR__)))

using Documenter
using JuBEMAnalysis
using CairoMakie

makedocs(
    sitename = "JuBEMAnalysis.jl",
    modules = [JuBEMAnalysis],
    remotes = nothing,
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        sidebar_sitename = true,
        collapselevel = 2,
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Processing & Analysis" => "processing.md",
        "Visualization & Plotting" => "plotting.md",
        "Data Export & IO" => "io.md",
        "API Reference" => "api.md",
    ]
)
