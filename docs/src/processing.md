# Processing & Analysis

`JuBEMAnalysis.jl` provides functions for data manipulation, symmetry checking, smoothing, and analytical dynamic benchmarks.

---

## Flexibility Extraction & Reciprocity

To extract a 1D complex frequency response series:

```julia
# Extract NuzFz (complex vector across all frequencies)
N_uz = get_flexibility(sim, :NuzFz)

# Extract with a sign multiplier
N_uy_neg = get_flexibility(sim, :NuyMx; sign = -1)
```

To evaluate cross-coupling reciprocity or symmetry errors ($N_1 - N_2$):

```julia
# Check difference between coupled terms
diff = get_cross_difference(sim, :NuxMy, :NphiyFx)

println("Max absolute asymmetry: ", maximum(abs.(diff)))
```

---

## LOESS Smoothing & Frequency Resampling

Simulations with finite boundary element discretizations can exhibit slight numerical undulations. `JuBEMAnalysis.jl` integrates `Loess.jl` for smoothing complex response functions.

### Single Component Smoothing

```julia
# Resample onto 1000 uniform frequency points using a 10% span
freqs_smooth, N_smooth = smooth_component(
    sim.freqs,
    get_flexibility(sim, :NuxFx);
    span = 0.1,
    n_resample = 1000
)
```

### Pre-Averaging Coupled Cross-Terms

For coupled terms (like $N_{uxMy}$ and $N_{\phi y Fx}$), theoretical reciprocity requires symmetry. You can average them prior to LOESS fitting via the `premean_data` argument:

```julia
N_cross1 = get_flexibility(sim, :NuxMy)
N_cross2 = get_flexibility(sim, :NphiyFx)

f_grid, N_coupled_smooth = smooth_component(
    sim.freqs,
    N_cross1;
    span = 0.1,
    premean_data = N_cross2
)
```

### Full Simulation Smoothing

To smooth all primary components at once:

```julia
f_grid, smoothed_dict = smooth_simulation(
    sim;
    span = 0.1,
    n_resample = 1000,
    cross_premean = true
)

# Access smoothed components
smoothed_Nuz = smoothed_dict["NuzFz"]
```

---

## Analytical Soil-on-Bedrock (SoB) Modes

For a homogeneous soil layer of thickness $h$ resting on a rigid bedrock base, the theoretical 1D analytical natural frequencies are given by:

$$\omega_n = c \frac{(2n - 1)\pi}{2h}, \quad n = 1, 2, \dots, N$$

where:
- For compressional / P-wave modes (vertical motion):
  $$c_p = \sqrt{\frac{\lambda + 2\mu}{\rho}}, \quad \lambda = \frac{2\nu\mu}{1 - 2\nu}, \quad \mu = G$$
- For shear / S-wave modes (horizontal motion):
  $$c_s = \sqrt{\frac{G}{\rho}}$$

```julia
# Compute the first 10 vertical natural frequencies for stratum depth h = 4.0 m
modes_p = soil_on_bedrock_modes(
    4.0, 10;
    G = 1.0,
    nu = 0.3,
    rho = 1.0,
    wave_type = :p_wave,
    freq_cap = 15.0 # Filter out frequencies above 15 rad/s (or Hz)
)
```
