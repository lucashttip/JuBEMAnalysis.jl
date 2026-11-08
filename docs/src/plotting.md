# Visualization & Plotting

`JuBEMAnalysis.jl` leverages `CairoMakie.jl` to generate clean, publication-ready vector and raster figures.

---

## Single Flexibility Component

Plot real and negative imaginary components (or magnitude) vs frequency:

```julia
using JuBEMAnalysis

fig = plot_flexibility(
    sim, :NuzFz;
    show_real = true,
    show_neg_imag = true,
    show_abs = false,
    title = "Vertical Flexibility vs Frequency"
)

save_figure(fig, "plots/NuzFz.png")
```

---

## Cross-Coupling Reciprocity Checks

Plot two coupled flexibilities on the same axis (with solid and dashed lines) to inspect reciprocity:

```julia
fig = plot_cross_coupling(
    sim, :NuxMy, :NphiyFx;
    title = "Cross-coupling reciprocity check"
)

save_figure(fig, "plots/Coupling_NuxMy_NphiyFx.png")
```

---

## Multi-Simulation Comparisons

Compare results across multiple mesh discretizations or domain truncation sizes:

```julia
fig_comp = plot_simulations_comparison(
    sims, :NuzFz;
    part = :abs, # Choose :abs, :real, :imag, or :neg_imag
    title = "Mesh Convergence - Vertical Flexibility"
)

save_figure(fig_comp, "plots/Convergence_NuzFz.png")
```

---

## Soil-on-Bedrock (SoB) Resonances

Superimpose analytical cutoff frequencies onto numerical flexibility curves:

```julia
fig_sob = plot_soil_on_bedrock(
    sim, :NuzFz;
    h = 8.0,
    n_modes = 12,
    wave_type = :p_wave
)

save_figure(fig_sob, "plots/SoB_NuzFz_modes.png")
```

---

## Full Matrix Grid Overview

Generate a $2 \times 3$ or multi-panel overview of all principal direct and coupled components:

```julia
fig_mat = plot_flexibility_matrix(sim)
save_figure(fig_mat, "plots/Flexibility_Matrix.png")
```

---

## Smoothed Response Comparison

Visualize LOESS smoothed curves overlaid against the raw and companion cross-term data:

```julia
fig_sm = plot_smoothed(
    sim, :NuxMy;
    span = 0.1,
    premean_comp = :NphiyFx
)

save_figure(fig_sm, "plots/Smoothed_NuxMy.png")
```

---

## Automated Batch Generation

Automate the generation and structured folder organization of all figures across multiple simulations:

```julia
# Automatically creates folders for each simulation and multi-sim comparisons
batch_plot_simulations(sims, "output_plots"; format = "png")
```
