# Data Export & IO

`JuBEMAnalysis.jl` provides input/output functions to interface between JuBEM's HDF5 archives and common scientific computing formats.

---

## CSV Export

Export all standard (or custom selected) flexibility components formatted with 17 digits of precision:

```julia
using JuBEMAnalysis

# Export standard 6-DoF direct and coupled components
export_csv(sim, "results/flexibilities.csv")

# Export custom selected components
export_csv(
    sim, "results/selected_flex.csv";
    components = [:NuzFz, :NuxFx, :NuyFy]
)
```

### Smoothed Data CSV Export

Export resampled frequencies and smoothed values:

```julia
f_grid, smoothed_dict = smooth_simulation(sim; span = 0.1, n_resample = 1000)
export_smoothed_csv("results/smoothed_data.csv", f_grid, smoothed_dict)
```

---

## MATLAB `.mat` File Export

Export frequency response matrices and frequency vectors to MATLAB v7.3 / v5 MAT files using `MAT.jl`:

```julia
export_mat(sim, "matlab/simulation_results.mat")
```

The resulting `.mat` file contains:
- `freqs`: Vector of excitation frequencies ($N_f \times 1$).
- `N_real`: Real part of flexibility tensor ($N_f \times 6 \times 6$).
- `N_imag`: Imaginary part of flexibility tensor ($N_f \times 6 \times 6$).
- `nelem`: Total number of elements (if available).
- `nelemt`: Truncated element count (if available).
