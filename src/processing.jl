module Processing

using Loess
using DataInterpolations
using LinearAlgebra
using Statistics

using ..Types

export get_flexibility, get_cross_difference, smooth_component, smooth_simulation,
       soil_on_bedrock_modes, p_wave_speed, s_wave_speed

"""
    get_flexibility(sim::SimulationResult, comp; sign=1) -> Vector{ComplexF64}

Extracts the 1D frequency response series for a specified flexibility component from `sim`.
"""
function get_flexibility(sim::SimulationResult, comp; sign=1)
    i, j = resolve_flex_coords(comp)
    return sim.N[:, i, j] .* sign
end

"""
    get_cross_difference(sim::SimulationResult, comp1, comp2; sign1=1, sign2=1) -> Vector{ComplexF64}

Calculates the difference `sign1 * N_comp1 - sign2 * N_comp2` across all frequencies.
Useful for checking reciprocity, symmetry, and cross-coupling errors.
"""
function get_cross_difference(sim::SimulationResult, comp1, comp2; sign1=1, sign2=1)
    d1 = get_flexibility(sim, comp1; sign=sign1)
    d2 = get_flexibility(sim, comp2; sign=sign2)
    return d1 .- d2
end

"""
    p_wave_speed(G, nu, rho) -> Float64

Computes the P-wave (compressional / dilatational) propagation velocity:
``c_p = \\sqrt{\\frac{\\lambda + 2\\mu}{\\rho}}`` where ``\\mu = G`` and ``\\lambda = \\frac{2\\nu\\mu}{1 - 2\\nu}``.
"""
function p_wave_speed(G::Real=1.0, nu::Real=0.3, rho::Real=1.0)
    mu = Float64(G)
    lambda = (2 * nu * mu) / (1 - 2 * nu)
    return sqrt((lambda + 2 * mu) / rho)
end

"""
    s_wave_speed(G, rho) -> Float64

Computes the S-wave (shear) propagation velocity:
``c_s = \\sqrt{\\frac{G}{\\rho}}``.
"""
function s_wave_speed(G::Real=1.0, rho::Real=1.0)
    return sqrt(Float64(G) / Float64(rho))
end

"""
    soil_on_bedrock_modes(h, n_modes; G=1.0, nu=0.3, rho=1.0, wave_type=:p_wave, freq_cap=Inf, in_hz=false) -> Vector{Float64}

Calculates the analytical natural frequencies for a soil stratum of depth `h` overlying bedrock.
``\\omega_n = c \\frac{(2n - 1)\\pi}{2h}, \\quad n = 1, 2, \\dots, N``

# Arguments
- `h`: Depth of the soil stratum.
- `n_modes`: Number of modes to compute.
- `G`, `nu`, `rho`: Elastic soil parameters (default: `G=1.0, nu=0.3, rho=1.0`).
- `wave_type`: `:p_wave` (default, for vertical/compressional modes) or `:s_wave` (for horizontal/shear modes).
- `freq_cap`: Maximum frequency threshold (modes above this are filtered out).
- `in_hz`: If `true`, returns frequencies in Hz (`f = \\omega / 2\\pi`). Default is `false` (angular frequency ``\\omega``).
"""
function soil_on_bedrock_modes(h::Real, n_modes::Integer;
                               G::Real=1.0, nu::Real=0.3, rho::Real=1.0,
                               wave_type::Symbol=:p_wave, freq_cap::Real=Inf, in_hz::Bool=false)
    c = if wave_type == :p_wave
        p_wave_speed(G, nu, rho)
    elseif wave_type == :s_wave
        s_wave_speed(G, rho)
    else
        error("Unknown wave_type: $wave_type. Choose :p_wave or :s_wave.")
    end

    wn = [c * (2 * i - 1) * pi / (2 * Float64(h)) for i in 1:n_modes]
    if in_hz
        wn = wn ./ (2 * pi)
    end

    return filter(w -> w <= freq_cap, wn)
end

"""
    smooth_component(freqs::AbstractVector, complex_data::AbstractVector{<:Complex};
                     span::Real=0.1, n_resample::Integer=1000, new_freqs=nothing,
                     premean_data=nothing) -> (resampled_freqs, smoothed_data)

Smooths complex frequency response data using locally estimated scatterplot smoothing (LOESS).

# Arguments
- `freqs`: Vector of raw excitation frequencies.
- `complex_data`: Vector of raw complex values.
- `span`: LOESS smoothing span (0 to 1, fraction of data points). Default: `0.1`.
- `n_resample`: Number of resampled frequency points (if `new_freqs` is not provided).
- `new_freqs`: Optional custom grid of frequencies for prediction.
- `premean_data`: Optional companion complex data vector (e.g. cross-term) to average with `complex_data` prior to smoothing.
"""
function smooth_component(freqs::AbstractVector, complex_data::AbstractVector{<:Complex};
                          span::Real=0.1, n_resample::Integer=1000, new_freqs=nothing,
                          premean_data=nothing)
    target_data = if !isnothing(premean_data)
        (complex_data .+ premean_data) ./ 2
    else
        complex_data
    end

    f_grid = if !isnothing(new_freqs)
        collect(Float64.(new_freqs))
    else
        collect(range(minimum(freqs), maximum(freqs), length=n_resample))
    end

    # Fit LOESS on real and imaginary parts independently
    model_real = loess(Float64.(freqs), Float64.(real.(target_data)), span=Float64(span))
    model_imag = loess(Float64.(freqs), Float64.(imag.(target_data)), span=Float64(span))

    pred_real = Loess.predict(model_real, f_grid)
    pred_imag = Loess.predict(model_imag, f_grid)

    smoothed = pred_real .+ pred_imag .* im
    return f_grid, smoothed
end

"""
    smooth_simulation(sim::SimulationResult; span=0.1, n_resample=1000, components=nothing, cross_premean=true)

Smooths multiple flexibility components for a `SimulationResult`.
Returns a tuple `(resampled_freqs, Dict{String, Vector{ComplexF64}})`.
"""
function smooth_simulation(sim::SimulationResult; span=0.1, n_resample=1000, components=nothing, cross_premean=true)
    default_specs = [
        (:NuzFz, nothing),
        (:NuxFx, nothing),
        (:NuyFy, nothing),
        (:NphizMz, nothing),
        (:NphiyMy, nothing),
        (:NphixMx, nothing),
        (:NuxMy, cross_premean ? :NphiyFx : nothing),
        (:NuyMx, cross_premean ? :NphixFy : nothing),
    ]

    specs = if isnothing(components)
        default_specs
    elseif components isa AbstractVector{<:Tuple}
        components
    else
        [(c, nothing) for c in components]
    end

    new_freqs = range(minimum(sim.freqs), maximum(sim.freqs), length=n_resample)
    smoothed_dict = Dict{String, Vector{ComplexF64}}()

    for (comp, pre_comp) in specs
        c_name = string(comp)
        raw_data = get_flexibility(sim, comp)
        pre_data = isnothing(pre_comp) ? nothing : get_flexibility(sim, pre_comp)
        
        _, sm = smooth_component(sim.freqs, raw_data; span=span, new_freqs=new_freqs, premean_data=pre_data)
        smoothed_dict[c_name] = sm
    end

    return collect(new_freqs), smoothed_dict
end

end # module Processing
