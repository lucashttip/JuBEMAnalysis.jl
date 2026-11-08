# JuBEMAnalysis.jl

**JuBEMAnalysis.jl** is a dedicated post-processing, physics analysis, and publication-quality visualization suite for boundary element method (BEM) simulation results produced by [JuBEM.jl](https://github.com/l235212/JuBEM.jl).

---

## 🎯 Purpose & Scope

JuBEM produces frequency-domain elastodynamic simulation outputs stored in HDF5 (`.h5`) format. `JuBEMAnalysis.jl` provides a streamlined and modular interface to:

1. **Read & Inspect**: Extract dynamic flexibility matrices $N(\omega) \in \mathbb{C}^{N_f \times 6 \times 6}$, compute truncated element counts excluding absorbing boundary/enclosing element tags, and manage simulation metadata.
2. **Process & Smooth**: Apply LOESS smoothing on complex frequency-response functions, pre-average symmetric cross-coupling components, and resample onto high-resolution frequency grids.
3. **Analyze Soil Dynamics**: Compute theoretical analytical natural frequencies and cutoff modes for Soil-on-Bedrock (SoB) strata.
4. **Visualize**: Generate vector-quality plots and comparison figures using `CairoMakie.jl`.
5. **Export**: Export processed, raw, and smoothed responses to CSV and MATLAB `.mat` formats.

---

## 🚀 Installation & Setup

Because `JuBEMAnalysis.jl` is designed as a companion package to `JuBEM.jl`, you can activate and develop it within your Julia environment:

```julia
using Pkg
Pkg.activate("path/to/JuBEMAnalysis")
Pkg.instantiate()
```

---

## 📖 Manual Outline

- [Getting Started](getting_started.md): How to load simulations and inspect results.
- [Processing & Analysis](processing.md): Flexibility extraction, LOESS smoothing, and Soil-on-Bedrock modes.
- [Visualization & Plotting](plotting.md): Creating publication-quality figures with CairoMakie.
- [Data Export & IO](io.md): Exporting data to CSV and MAT files.
- [API Reference](api.md): Complete list of exported structs, functions, and docstrings.
