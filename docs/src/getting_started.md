# Getting Started

## Loading Simulation Results

JuBEM saves frequency response results in `.h5` files. `JuBEMAnalysis.jl` loads these results into a unified [`SimulationResult`](@ref) structure.

### Single Simulation

```julia
using JuBEMAnalysis

# Load simulation result from HDF5
sim = load_simulation(
    "sims/h5/A4_nft=100_fs=42a_ne2=48_nee=8_ns2=8.h5";
    label = "Mesh 4.2",
    exclude_tags = [3, 4], # Exclude enclosing/boundary elements from element count
    h = 8.0                # Custom metadata can be passed directly as kwargs
)

println(sim)
```

The resulting `sim` object contains:
- `sim.freqs`: Vector of excitation frequencies in Hz.
- `sim.N`: 3D tensor of dynamic flexibility matrices `[n_freq, 6, 6]`.
- `sim.mesh`: JuBEM mesh structure (nodes, elements, tags).
- `sim.problem`: JuBEM model problem configuration.
- `sim.metadata`: Dictionary with properties such as `:nelem` (total elements), `:nelemt` (truncated elements), `:h` (stratum depth), and any extra keyword arguments.

---

### Multiple Simulations (Batch Loading)

You can load multiple simulations at once for convergence studies or parametric sweeps using [`load_simulations`](@ref):

```julia
specs = [
    Dict("filename" => "sims/h5/A1_nft=36_fs=6a.h5",  "label" => "nft=36, fs=6a"),
    Dict("filename" => "sims/h5/A1_nft=64_fs=6a.h5",  "label" => "nft=64, fs=6a"),
    Dict("filename" => "sims/h5/A1_nft=100_fs=6a.h5", "label" => "nft=100, fs=6a"),
]

sims = load_simulations(specs; exclude_tags = [3, 4])
```

---

## 6-DoF Flexibility Coordinates & Naming

Flexibility components can be referenced interchangeably by **Symbol**, **String**, or `(row, col)` integer coordinates:

| Component Name | Description | Matrix Coordinate `(row, col)` |
| :--- | :--- | :--- |
| `:NuzFz` or `:Nz` | Vertical displacement / vertical force | `(1, 1)` |
| `:NuxFx` or `:Nx` | Horizontal X displacement / force X | `(2, 2)` |
| `:NuyFy` or `:Ny` | Horizontal Y displacement / force Y | `(3, 3)` |
| `:NphizMz` or `:NϕzMz` | Torsional rotation Z / torque Z | `(4, 4)` |
| `:NphiyMy` or `:NϕyMy` | Rocking rotation Y / moment Y | `(5, 5)` |
| `:NphixMx` or `:NϕxMx` | Rocking rotation X / moment X | `(6, 6)` |
| `:NuxMy` | Coupled horizontal X / moment Y | `(2, 6)` |
| `:NphiyFx` or `:NϕyFx` | Coupled rocking Y / force X | `(5, 3)` |
| `:NuyMx` | Coupled horizontal Y / moment X | `(3, 5)` |
| `:NphixFy` or `:NϕxFy` | Coupled rocking X / force Y | `(6, 2)` |

Use [`resolve_flex_coords`](@ref) to translate any naming alias into matrix coordinates.
