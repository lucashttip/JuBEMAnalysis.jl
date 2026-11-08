# JuBEMAnalysis.jl

[![Build Status](https://github.com/l235212/JuBEMAnalysis.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/l235212/JuBEMAnalysis.jl/actions/workflows/CI.yml?query=branch%3Amaster)

`JuBEMAnalysis.jl` is a post-processing and analysis package for boundary element method (BEM) simulation results produced by [JuBEM.jl](https://github.com/l235212/JuBEM.jl).

---

## 🌟 Key Features

- **HDF5 Result Loading**: Parse `.h5` output archives containing frequency-dependent flexibility matrices ($N(\omega)$), meshes, and model metadata.
- **Dynamic Flexibility Extraction**: Direct lookup for 6-DoF direct and coupled terms (`:NuzFz`, `:NuxFx`, `:NuyFy`, `:NphizMz`, `:NphiyMy`, `:NphixMx`, cross-terms like `:NuxMy`, `:NphiyFx`, etc.).
- **LOESS Smoothing & Resampling**: Apply locally estimated scatterplot smoothing (`Loess.jl`) on complex response functions, pre-average symmetric cross-coupling components, and interpolate onto dense frequency grids.
- **Analytical Soil-on-Bedrock (SoB) Modes**: Calculate vertical and horizontal resonance cut-off frequencies $\omega_n = c \frac{(2n-1)\pi}{2h}$ for stratified media.
- **Publication-Quality Visualizations**: Powered by `CairoMakie.jl`, featuring real, imaginary, magnitude, and difference plots, cross-coupling reciprocity checks, and multi-mesh convergence overlays.
- **Exporting Tools**: Export processed and smoothed dynamic flexibility matrices to formatted CSVs and MATLAB `.mat` files.
- **Batch Processing**: Automatically generate and organize complete suites of figures and tabular data across multiple simulations.

---

## 🚀 Quick Start

### 1. Load a Simulation

```julia
using JuBEMAnalysis

# Load a single simulation result
sim = load_simulation("sims/h5/A4_nft=100_fs=42a.h5"; label="Mesh 4.2", exclude_tags=[3, 4])

# Or load multiple simulations for comparison
sims = load_simulations([
    Dict("filename" => "sims/h5/A1_nft=36_fs=6a.h5",  "label" => "nft=36"),
    Dict("filename" => "sims/h5/A1_nft=64_fs=6a.h5",  "label" => "nft=64"),
    Dict("filename" => "sims/h5/A1_nft=100_fs=6a.h5", "label" => "nft=100"),
])
```

---

### 2. Plotting with CairoMakie

```julia
using CairoMakie

# 1. Single flexibility component (Real and -Imag)
fig1 = plot_flexibility(sim, :NuzFz)
save_figure(fig1, "plots/NuzFz.png")

# 2. Compare cross-coupling terms (reciprocity check)
fig2 = plot_cross_coupling(sim, :NuxMy, :NphiyFx)
save_figure(fig2, "plots/Cross_NuxMy_NphiyFx.png")

# 3. Multi-simulation mesh convergence
fig3 = plot_simulations_comparison(sims, :NuzFz; part=:abs)
save_figure(fig3, "plots/Convergence_NuzFz_abs.png")

# 4. Soil-on-bedrock with analytical resonance frequencies
fig_sob = plot_soil_on_bedrock(sim, :NuzFz; h=8.0, n_modes=10)
save_figure(fig_sob, "plots/SoB_NuzFz.png")

# 5. Full flexibility matrix overview (6 diagonal & key coupled terms)
fig_mat = plot_flexibility_matrix(sim)
save_figure(fig_mat, "plots/flex_matrix.png")
```

---

### 3. LOESS Smoothing & Pre-averaging

```julia
# Smooth a single component
freqs_smooth, N_smooth = smooth_component(sim.freqs, get_flexibility(sim, :NuzFz); span=0.1, n_resample=1000)

# Smooth an entire simulation result and export to CSV
f_grid, smoothed_dict = smooth_simulation(sim; span=0.1, n_resample=1000)
export_smoothed_csv("plots/smoothed_data.csv", f_grid, smoothed_dict)

# Plot smoothed curve over original data
fig_sm = plot_smoothed(sim, :NuxMy; span=0.1, premean_comp=:NphiyFx)
save_figure(fig_sm, "plots/smoothed_NuxMy.png")
```

---

### 4. Data Export

```julia
# Export all components to CSV
export_csv(sim, "csv/simulation_results.csv")

# Export to MATLAB .mat file
export_mat(sim, "mat/simulation_results.mat")
```

---

### 5. Automated Batch Processing

```julia
# Generates individual component plots, matrix grids, SoB overlays, and comparisons
batch_plot_simulations(sims, "output_plots"; format="png")
```
