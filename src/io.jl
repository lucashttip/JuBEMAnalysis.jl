module IO

using HDF5
using MAT
using Printf
using DelimitedFiles
using JuBEM

using ..Types

export load_simulation, load_simulations, export_csv, export_mat, export_smoothed_csv

"""
    load_simulation(filepath::AbstractString; label=nothing, load_mesh=true, exclude_tags=[3, 4], kwargs...) -> SimulationResult

Loads simulation results from a JuBEM HDF5 output file (`.h5`).

# Arguments
- `filepath`: Path to the `.h5` file.
- `label`: Custom label for the simulation (defaults to filename without extension).
- `load_mesh`: Whether to load the mesh and model structures (default: `true`).
- `exclude_tags`: Vector of boundary element tags to exclude when computing truncated element count `nelemt` (default: `[3, 4]`).
- Additional keyword arguments are stored directly in `metadata`.
"""
function load_simulation(filepath::AbstractString; label=nothing, load_mesh=true, exclude_tags=[3, 4], kwargs...)
    if !isfile(filepath)
        error("JuBEM result file not found: '$(filepath)'")
    end

    filename = basename(filepath)
    sim_label = isnothing(label) ? splitext(filename)[1] : string(label)

    # Read flexibility matrices and frequencies from JuBEM readout
    N, freqs = JuBEM.getflex_out(filepath)

    mesh = nothing
    problem = nothing
    material = nothing
    solver_var = nothing

    metadata = Dict{Symbol, Any}(kwargs...)

    if load_mesh
        try
            mesh, material, problem, solver_var = JuBEM.readvars_out(filepath)
            nelem = JuBEM.totalelem(mesh)
            metadata[:nelem] = nelem

            # Calculate truncated elements excluding specific tags
            if !isempty(exclude_tags)
                tags_present = filter(t -> !isempty(JuBEM.get_elements_from_tags(mesh, [t])), exclude_tags)
                if !isempty(tags_present)
                    nelemee = length(JuBEM.get_elements_from_tags(mesh, tags_present))
                    metadata[:nelemt] = nelem - nelemee
                    metadata[:excluded_tags] = tags_present
                else
                    metadata[:nelemt] = nelem
                end
            else
                metadata[:nelemt] = nelem
            end
        catch e
            @warn "Could not load mesh / model vars from $(filename): $e"
        end
    end

    return SimulationResult(
        abspath(filepath),
        filename,
        sim_label,
        freqs,
        N,
        mesh,
        problem,
        metadata
    )
end

"""
    load_simulations(specs::AbstractVector; kwargs...) -> Vector{SimulationResult}

Loads multiple simulations given a vector of filepaths or dictionaries specifying metadata.

# Example
```julia
sims = load_simulations([
    Dict("filename" => "path/to/sim1.h5", "label" => "Mesh A", "nft" => 64),
    Dict("filename" => "path/to/sim2.h5", "label" => "Mesh B", "nft" => 100)
])
```
"""
function load_simulations(specs::AbstractVector; kwargs...)
    results = SimulationResult[]
    for spec in specs
        if spec isa AbstractString
            push!(results, load_simulation(spec; kwargs...))
        elseif spec isa AbstractDict
            # Extract filepath from "filename", "path", or "filepath"
            fp = get(spec, "filepath", get(spec, "filename", get(spec, "path", nothing)))
            if isnothing(fp)
                error("Dictionary specification must contain 'filename', 'filepath', or 'path'. Got: $spec")
            end
            lbl = get(spec, "label", nothing)
            exclude_tags = get(spec, "exclude_tags", [3, 4])
            
            # Remaining entries as metadata
            meta_kwargs = Dict{Symbol, Any}(
                Symbol(k) => v for (k, v) in spec if !(k in ["filepath", "filename", "path", "label", "exclude_tags"])
            )
            merge!(meta_kwargs, kwargs)
            push!(results, load_simulation(fp; label=lbl, exclude_tags=exclude_tags, meta_kwargs...))
        else
            error("Unsupported simulation spec type: $(typeof(spec))")
        end
    end
    return results
end

"""
    export_csv(sim::SimulationResult, outpath::AbstractString; fmt="%.17f", components=nothing)

Exports all standard (or specified) flexibility components of a simulation result to a CSV file.
"""
function export_csv(sim::SimulationResult, outpath::AbstractString; fmt="%.17f", components=nothing)
    mkpath(dirname(abspath(outpath)))

    default_comps = [
        ("NuzFz", (1, 1)),
        ("NuxFx", (2, 2)),
        ("NuyFy", (3, 3)),
        ("NphizMz", (4, 4)),
        ("NphixMx", (6, 6)),
        ("NphiyMy", (5, 5)),
        ("NuxMy", (2, 6)),
        ("NphiyFx", (5, 3)),
        ("NuyMx", (3, 5)),
        ("NphixFy", (6, 2)),
    ]

    comps_to_export = if isnothing(components)
        default_comps
    else
        [(string(c), resolve_flex_coords(c)) for c in components]
    end

    formatter(x) = @sprintf("%.17f", x)

    open(outpath, "w") do io
        # Header
        headers = ["frequency_hz"]
        for (cname, _) in comps_to_export
            push!(headers, "real_$(cname)", "imag_$(cname)")
        end
        println(io, join(headers, ","))

        # Rows
        nf = length(sim.freqs)
        for f_idx in 1:nf
            row = [formatter(sim.freqs[f_idx])]
            for (_, coords) in comps_to_export
                val = sim.N[f_idx, coords[1], coords[2]]
                push!(row, formatter(real(val)), formatter(imag(val)))
            end
            println(io, join(row, ","))
        end
    end

    return outpath
end

"""
    export_mat(sim::SimulationResult, outpath::AbstractString)

Exports frequencies and flexibility matrices (real and imaginary parts) to a MATLAB `.mat` file.
"""
function export_mat(sim::SimulationResult, outpath::AbstractString)
    mkpath(dirname(abspath(outpath)))
    file = matopen(outpath, "w")
    try
        write(file, "freqs", sim.freqs)
        write(file, "N_real", real.(sim.N))
        write(file, "N_imag", imag.(sim.N))
        if haskey(sim.metadata, :nelem)
            write(file, "nelem", Float64(sim.metadata[:nelem]))
        end
        if haskey(sim.metadata, :nelemt)
            write(file, "nelemt", Float64(sim.metadata[:nelemt]))
        end
    finally
        close(file)
    end
    return outpath
end

"""
    export_smoothed_csv(outpath::AbstractString, freqs::AbstractVector, data_dict::AbstractDict)

Exports a resampled frequency vector and smoothed flexibility components to a CSV file.
"""
function export_smoothed_csv(outpath::AbstractString, freqs::AbstractVector, data_dict::AbstractDict)
    mkpath(dirname(abspath(outpath)))
    headers = ["frequency"]
    cols = [Float64.(collect(freqs))]

    for (name, data) in data_dict
        push!(headers, "$(name)(real)", "$(name)(imag)")
        push!(cols, Float64.(real.(data)), Float64.(imag.(data)))
    end

    open(outpath, "w") do io
        println(io, join(headers, ","))
        writedlm(io, hcat(cols...), ',')
    end

    return outpath
end

end # module IO
