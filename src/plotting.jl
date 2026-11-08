module Plotting

using CairoMakie
using Printf

using ..Types
using ..Processing

export plot_flexibility, plot_flexibility_matrix, plot_simulations_comparison,
       plot_cross_coupling, plot_soil_on_bedrock, plot_smoothed, batch_plot_simulations,
       save_figure

# Publication-quality standard theme for CairoMakie
function get_standard_theme()
    Theme(
        fontsize = 14,
        font = "TeX Gyre Heros",
        Axis = (
            xgridvisible = true,
            ygridvisible = true,
            xgridcolor = RGBAf(0.85, 0.85, 0.85, 0.6),
            ygridcolor = RGBAf(0.85, 0.85, 0.85, 0.6),
            xgridstyle = :dash,
            ygridstyle = :dash,
            xminorticksvisible = true,
            yminorticksvisible = true,
            spinewidth = 1.2,
            titlesize = 15,
            xlabelsize = 14,
            ylabelsize = 14,
        ),
        Lines = (
            linewidth = 2.0,
        ),
        Legend = (
            framevisible = true,
            framecolor = RGBAf(0.7, 0.7, 0.7, 0.8),
            backgroundcolor = RGBAf(1.0, 1.0, 1.0, 0.9),
            labelsize = 12,
        )
    )
end

"""
    plot_flexibility(sim::SimulationResult, comp; show_real=true, show_neg_imag=true, show_abs=false,
                     title=nothing, xlabel="Frequency (Hz)", ylabel="Flexibility", size=(800, 500)) -> Figure

Plots real, negative-imaginary, and/or magnitude of a flexibility component vs frequency.
"""
function plot_flexibility(sim::SimulationResult, comp;
                          show_real=true, show_neg_imag=true, show_abs=false,
                          title=nothing, xlabel="Frequency (Hz)", ylabel="Flexibility",
                          size=(800, 500))
    with_theme(get_standard_theme()) do
        fig = Figure(size=size)
        c_name = string(comp)
        
        sim_desc = haskey(sim.metadata, :nelemt) ? "$(sim.label), ne=$(sim.metadata[:nelemt])" : sim.label
        plot_title = isnothing(title) ? "$(c_name) vs Frequency - $(sim_desc)" : title

        ax = Axis(fig[1, 1], title=plot_title, xlabel=xlabel, ylabel=ylabel)
        data = get_flexibility(sim, comp)

        if show_real
            lines!(ax, sim.freqs, real.(data), label="$(c_name) (Real)", color=:black, linewidth=2.0)
        end
        if show_neg_imag
            lines!(ax, sim.freqs, -imag.(data), label="$(c_name) (-Imag)", color=:red, linewidth=2.0)
        end
        if show_abs
            lines!(ax, sim.freqs, abs.(data), label="$(c_name) (Abs)", color=:blue, linewidth=2.0)
        end

        axislegend(ax, position=:rt)
        return fig
    end
end

"""
    plot_cross_coupling(sim::SimulationResult, comp1, comp2; sign1=1, sign2=-1,
                        title=nothing, xlabel="Frequency (Hz)", ylabel="Flexibility", size=(800, 500)) -> Figure

Plots two flexibility components (or symmetric cross terms) together to visualize reciprocity and coupling.
"""
function plot_cross_coupling(sim::SimulationResult, comp1, comp2;
                             sign1=1, sign2=1,
                             title=nothing, xlabel="Frequency (Hz)", ylabel="Flexibility",
                             size=(800, 500))
    with_theme(get_standard_theme()) do
        fig = Figure(size=size)
        lbl1 = string(comp1)
        lbl2 = string(comp2)
        
        sim_desc = haskey(sim.metadata, :nelemt) ? "$(sim.label), ne=$(sim.metadata[:nelemt])" : sim.label
        plot_title = isnothing(title) ? "$(lbl1) and $(lbl2) - $(sim_desc)" : title

        ax = Axis(fig[1, 1], title=plot_title, xlabel=xlabel, ylabel=ylabel)

        data1 = get_flexibility(sim, comp1; sign=sign1)
        data2 = get_flexibility(sim, comp2; sign=sign2)

        lines!(ax, sim.freqs, real.(data1), label="$(lbl1) (Real)", color=:black, linestyle=:solid, linewidth=2.0)
        lines!(ax, sim.freqs, -imag.(data1), label="$(lbl1) (-Imag)", color=:red, linestyle=:solid, linewidth=2.0)
        lines!(ax, sim.freqs, real.(data2), label="$(lbl2) (Real)", color=:blue, linestyle=:dash, linewidth=1.5)
        lines!(ax, sim.freqs, -imag.(data2), label="$(lbl2) (-Imag)", color=:green, linestyle=:dash, linewidth=1.5)

        axislegend(ax, position=:rt)
        return fig
    end
end

"""
    plot_simulations_comparison(sims::AbstractVector{SimulationResult}, comp;
                                part=:abs, title=nothing, xlabel="Frequency (Hz)",
                                ylabel=nothing, colormap=:viridis, size=(850, 550)) -> Figure

Compares multiple simulations (e.g. mesh convergence or truncation study) for a single flexibility component.
`part` can be `:abs`, `:real`, `:imag`, `:neg_imag`, or `:diff` (requires 2 components or relative to first).
"""
function plot_simulations_comparison(sims::AbstractVector{SimulationResult}, comp;
                                     part=:abs, title=nothing, xlabel="Frequency (Hz)",
                                     ylabel=nothing, colormap=:tab10, size=(850, 550))
    with_theme(get_standard_theme()) do
        fig = Figure(size=size)
        c_name = string(comp)

        part_str = part == :abs ? "(Abs)" :
                   part == :real ? "(Real)" :
                   part == :imag ? "(Imag)" :
                   part == :neg_imag ? "(-Imag)" : string(part)

        y_label = isnothing(ylabel) ? "$(c_name) $(part_str)" : ylabel
        plot_title = isnothing(title) ? "$(c_name) $(part_str) vs Frequency" : title

        ax = Axis(fig[1, 1], title=plot_title, xlabel=xlabel, ylabel=y_label)

        n_sims = length(sims)
        colors = Makie.resample_cmap(colormap, max(n_sims, 2))

        for (idx, sim) in enumerate(sims)
            data = get_flexibility(sim, comp)
            y_vals = if part == :abs
                abs.(data)
            elseif part == :real
                real.(data)
            elseif part == :imag
                imag.(data)
            elseif part == :neg_imag
                -imag.(data)
            else
                error("Unsupported part: $part. Choose :abs, :real, :imag, or :neg_imag")
            end

            sim_lbl = if haskey(sim.metadata, :nelemt)
                "$(sim.label), ne=$(sim.metadata[:nelemt])"
            else
                sim.label
            end

            lines!(ax, sim.freqs, y_vals, label=sim_lbl, color=colors[idx], linewidth=2.0)
        end

        axislegend(ax, position=:rt)
        return fig
    end
end

"""
    plot_soil_on_bedrock(sim::SimulationResult, comp; h=nothing, n_modes=14, freq_cap=nothing,
                         G=1.0, nu=0.3, rho=1.0, wave_type=:p_wave,
                         title=nothing, xlabel="Frequency (Hz)", ylabel="Flexibility", size=(800, 500)) -> Figure

Plots flexibility response with vertical dashed lines representing analytical soil-on-bedrock resonance frequencies.
"""
function plot_soil_on_bedrock(sim::SimulationResult, comp;
                              h=nothing, n_modes=14, freq_cap=nothing,
                              G=1.0, nu=0.3, rho=1.0, wave_type=:p_wave,
                              title=nothing, xlabel="Frequency (Hz)", ylabel="Flexibility",
                              size=(800, 500))
    stratum_h = if !isnothing(h)
        h
    elseif haskey(sim.metadata, :h)
        sim.metadata[:h]
    else
        error("Stratum depth `h` must be provided either as argument or in simulation metadata.")
    end

    f_cap = isnothing(freq_cap) ? maximum(sim.freqs) : freq_cap
    wn_modes = soil_on_bedrock_modes(stratum_h, n_modes; G=G, nu=nu, rho=rho, wave_type=wave_type, freq_cap=f_cap)

    with_theme(get_standard_theme()) do
        fig = Figure(size=size)
        c_name = string(comp)
        
        sim_desc = haskey(sim.metadata, :nelemt) ? "$(sim.label), ne=$(sim.metadata[:nelemt]), h=$(stratum_h)" : "$(sim.label), h=$(stratum_h)"
        plot_title = isnothing(title) ? "$(c_name) vs Frequency - $(sim_desc)" : title

        ax = Axis(fig[1, 1], title=plot_title, xlabel=xlabel, ylabel=ylabel)
        data = get_flexibility(sim, comp)

        lines!(ax, sim.freqs, real.(data), label="$(c_name) (Real)", color=:black, linewidth=2.0)
        lines!(ax, sim.freqs, -imag.(data), label="$(c_name) (-Imag)", color=:red, linewidth=2.0)

        if !isempty(wn_modes)
            vlines!(ax, wn_modes, label="Analytical Modes", color=:blue, linestyle=:dash, linewidth=1.5)
        end

        axislegend(ax, position=:rt)
        return fig
    end
end

"""
    plot_smoothed(sim::SimulationResult, comp; span=0.1, n_resample=1000, premean_comp=nothing,
                  title=nothing, xlabel="Frequency (Hz)", ylabel=nothing, size=(800, 500)) -> Figure

Plots smoothed flexibility curves alongside the raw (original) data and any cross-terms used for pre-averaging.
"""
function plot_smoothed(sim::SimulationResult, comp;
                       span=0.1, n_resample=1000, premean_comp=nothing,
                       title=nothing, xlabel="Frequency (Hz)", ylabel=nothing,
                       size=(800, 500))
    c_name = string(comp)
    raw_data = get_flexibility(sim, comp)
    pre_data = isnothing(premean_comp) ? nothing : get_flexibility(sim, premean_comp)

    f_smoothed, smoothed_data = smooth_component(sim.freqs, raw_data; span=span, n_resample=n_resample, premean_data=pre_data)

    with_theme(get_standard_theme()) do
        fig = Figure(size=size)
        y_lbl = isnothing(ylabel) ? c_name : ylabel
        plot_title = isnothing(title) ? "$(c_name) vs Frequency - $(sim.label) (LOESS span=$(span))" : title

        ax = Axis(fig[1, 1], title=plot_title, xlabel=xlabel, ylabel=y_lbl)

        # Smoothed
        lines!(ax, f_smoothed, real.(smoothed_data), label="Real (Smoothed)", color=:black, linewidth=2.0)
        lines!(ax, f_smoothed, -imag.(smoothed_data), label="-Imag (Smoothed)", color=:red, linewidth=2.0)

        # Original
        lines!(ax, sim.freqs, real.(raw_data), label="Real (Original)", color=:black, linestyle=:dash, linewidth=1.0)
        lines!(ax, sim.freqs, -imag.(raw_data), label="-Imag (Original)", color=:red, linestyle=:dash, linewidth=1.0)

        # Premean cross term if present
        if !isnothing(pre_data)
            lines!(ax, sim.freqs, real.(pre_data), label="Real (Cross)", color=:blue, linestyle=:dash, linewidth=1.0)
            lines!(ax, sim.freqs, -imag.(pre_data), label="-Imag (Cross)", color=:green, linestyle=:dash, linewidth=1.0)
        end

        axislegend(ax, position=:rt)
        return fig
    end
end

"""
    plot_flexibility_matrix(sim::SimulationResult; size=(1200, 800)) -> Figure

Plots all diagonal components and key cross-terms of the flexibility matrix in a multi-panel figure.
"""
function plot_flexibility_matrix(sim::SimulationResult; size=(1200, 800))
    comps = [
        :NuzFz, :NuxFx, :NuyFy,
        :NphizMz, :NphiyMy, :NphixMx
    ]
    with_theme(get_standard_theme()) do
        fig = Figure(size=size)
        for (i, c) in enumerate(comps)
            row = (i - 1) ÷ 3 + 1
            col = (i - 1) % 3 + 1
            ax = Axis(fig[row, col], title=string(c), xlabel="Freq (Hz)", ylabel="Flexibility")
            data = get_flexibility(sim, c)
            lines!(ax, sim.freqs, real.(data), label="Real", color=:black, linewidth=1.8)
            lines!(ax, sim.freqs, -imag.(data), label="-Imag", color=:red, linewidth=1.8)
            axislegend(ax, position=:rt, labelsize=10)
        end
        return fig
    end
end

"""
    save_figure(fig::Figure, filepath::AbstractString; px_per_unit=2)

Saves a Makie Figure to disk (e.g. `.png` or `.pdf`).
"""
function save_figure(fig::Figure, filepath::AbstractString; px_per_unit=2)
    mkpath(dirname(abspath(filepath)))
    save(filepath, fig; px_per_unit=px_per_unit)
    return filepath
end

"""
    batch_plot_simulations(sims::AbstractVector{SimulationResult}, outdir::AbstractString;
                           components=[:NuzFz, :NuxFx, :NuyFy, :NphizMz, :NphiyMy, :NphixMx],
                           format="png")

Generates and saves standard suites of figures for individual simulations and multi-simulation comparisons.
"""
function batch_plot_simulations(sims::AbstractVector{SimulationResult}, outdir::AbstractString;
                                components=[:NuzFz, :NuxFx, :NuyFy, :NphizMz, :NphiyMy, :NphixMx],
                                format="png")
    mkpath(outdir)

    # 1. Individual plots for each simulation
    for sim in sims
        sim_dir = joinpath(outdir, sim.label)
        mkpath(sim_dir)

        # Matrix overview
        mat_fig = plot_flexibility_matrix(sim)
        save_figure(mat_fig, joinpath(sim_dir, "flexibility_matrix.$(format)"))

        # Individual components
        for comp in components
            c_name = string(comp)
            fig = plot_flexibility(sim, comp)
            save_figure(fig, joinpath(sim_dir, "$(c_name).$(format)"))
        end

        # Soil on bedrock if `h` is present
        if haskey(sim.metadata, :h)
            fig_sob = plot_soil_on_bedrock(sim, :NuzFz)
            save_figure(fig_sob, joinpath(sim_dir, "SoB_NuzFz.$(format)"))
        end
    end

    # 2. Multi-simulation comparisons if > 1 simulation
    if length(sims) > 1
        comp_dir = joinpath(outdir, "comparisons")
        mkpath(comp_dir)
        for comp in components
            c_name = string(comp)
            for part in [:abs, :real, :neg_imag]
                fig_comp = plot_simulations_comparison(sims, comp; part=part)
                save_figure(fig_comp, joinpath(comp_dir, "compare_$(c_name)_$(part).$(format)"))
            end
        end
    end

    return outdir
end

end # module Plotting
