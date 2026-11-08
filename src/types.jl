module Types

using JuBEM

export SimulationResult, DOF_MAP, FLEX_INDEX_MAP, resolve_flex_coords

"""
Standard map from 6-DoF names to matrix indices (1 to 6).
- 1: uz / Fz
- 2: ux / Fx
- 3: uy / Fy
- 4: phiz / Mz
- 5: phiy / My
- 6: phix / Mx
"""
const DOF_MAP = Dict{Symbol, Int}(
    :uz => 1, :fz => 1, :Fz => 1, :z => 1,
    :ux => 2, :fx => 2, :Fx => 2, :x => 2,
    :uy => 3, :fy => 3, :Fy => 3, :y => 3,
    :phiz => 4, :mz => 4, :Mz => 4, :ϕz => 4, :θz => 4,
    :phiy => 5, :my => 5, :My => 5, :ϕy => 5, :θy => 5,
    :phix => 6, :mx => 6, :Mx => 6, :ϕx => 6, :θx => 6
)

"""
Standard named flexibility components mapped to matrix coordinates `(row, col)`.
"""
const FLEX_INDEX_MAP = Dict{Symbol, Tuple{Int, Int}}(
    # Direct terms
    :NuzFz   => (1, 1),
    :Nz      => (1, 1),
    :NuxFx   => (2, 2),
    :Nx      => (2, 2),
    :NuyFy   => (3, 3),
    :Ny      => (3, 3),
    :NphizMz => (4, 4),
    :NϕzMz   => (4, 4),
    :NphiyMy => (5, 5),
    :NϕyMy   => (5, 5),
    :NphixMx => (6, 6),
    :NϕxMx   => (6, 6),

    # Cross terms (standard dynamic stiffness/flexibility ordering)
    :NuxMy   => (2, 6),
    :NuyMx   => (3, 5),
    :NphixFy => (6, 2),
    :NϕxFy   => (6, 2),
    :NphiyFx => (5, 3),
    :NϕyFx   => (5, 3),
)

"""
    resolve_flex_coords(comp) -> Tuple{Int, Int}

Resolves a flexibility component specification (Symbol, String, or Tuple) into `(i, j)` coordinates.
"""
function resolve_flex_coords(coords::Tuple{Int, Int})
    return coords
end

function resolve_flex_coords(comp::Symbol)
    if haskey(FLEX_INDEX_MAP, comp)
        return FLEX_INDEX_MAP[comp]
    end
    return resolve_flex_coords(string(comp))
end

function resolve_flex_coords(comp_str::AbstractString)
    sym = Symbol(comp_str)
    if haskey(FLEX_INDEX_MAP, sym)
        return FLEX_INDEX_MAP[sym]
    end

    # Handle greek phi / unicode substitutions
    clean_str = replace(comp_str, "ϕ" => "phi", "θ" => "phi")
    sym_clean = Symbol(clean_str)
    if haskey(FLEX_INDEX_MAP, sym_clean)
        return FLEX_INDEX_MAP[sym_clean]
    end

    if clean_str in ["NuxMy", "uxMy"]
        return (2, 6)
    elseif clean_str in ["NuyMx", "uyMx"]
        return (3, 5)
    elseif clean_str in ["NphixFy", "phixFy"]
        return (6, 2)
    elseif clean_str in ["NphiyFx", "phiyFx"]
        return (5, 3)
    end

    error("Unknown flexibility component: '$(comp_str)'. Available names: $(keys(FLEX_INDEX_MAP)) or provide (row, col) tuple.")
end

"""
    SimulationResult

Data structure representing the results of a JuBEM simulation.

# Fields
- `filepath`: Absolute or relative path to the `.h5` file.
- `filename`: Base name of the file.
- `label`: Descriptive label for plotting/reports.
- `freqs`: Vector of excitation frequencies in Hz.
- `N`: 3D tensor of dynamic flexibility matrices `[n_freq, 6, 6]`.
- `mesh`: Mesh object (if loaded, otherwise `nothing`).
- `problem`: Model / problem object (if loaded, otherwise `nothing`).
- `metadata`: Dictionary of simulation parameters (e.g. `nelem`, `nelemt`, `nft`, `fs`, `h`, etc.).
"""
struct SimulationResult
    filepath::String
    filename::String
    label::String
    freqs::Vector{Float64}
    N::Array{ComplexF64, 3}
    mesh::Any
    problem::Any
    metadata::Dict{Symbol, Any}
end

function Base.show(io::IO, sim::SimulationResult)
    nf = length(sim.freqs)
    f_min = isempty(sim.freqs) ? 0.0 : minimum(sim.freqs)
    f_max = isempty(sim.freqs) ? 0.0 : maximum(sim.freqs)
    nelem_str = haskey(sim.metadata, :nelemt) ? ", nelemt=$(sim.metadata[:nelemt])" : ""
    print(io, "SimulationResult(\"$(sim.filename)\", label=\"$(sim.label)\", $(nf) freqs [$(round(f_min, digits=2)) - $(round(f_max, digits=2)) Hz]$(nelem_str))")
end

end # module Types
