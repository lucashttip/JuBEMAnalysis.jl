# API Reference

## Types & Coordinate Resolution

```@docs
JuBEMAnalysis.SimulationResult
JuBEMAnalysis.resolve_flex_coords
JuBEMAnalysis.Types.DOF_MAP
JuBEMAnalysis.Types.FLEX_INDEX_MAP
```

---

## Loading & File I/O

```@docs
JuBEMAnalysis.load_simulation
JuBEMAnalysis.load_simulations
JuBEMAnalysis.export_csv
JuBEMAnalysis.export_mat
JuBEMAnalysis.export_smoothed_csv
```

---

## Processing & Physics

```@docs
JuBEMAnalysis.get_flexibility
JuBEMAnalysis.get_cross_difference
JuBEMAnalysis.smooth_component
JuBEMAnalysis.smooth_simulation
JuBEMAnalysis.soil_on_bedrock_modes
JuBEMAnalysis.p_wave_speed
JuBEMAnalysis.s_wave_speed
```

---

## Visualization & Plotting

```@docs
JuBEMAnalysis.plot_flexibility
JuBEMAnalysis.plot_cross_coupling
JuBEMAnalysis.plot_simulations_comparison
JuBEMAnalysis.plot_soil_on_bedrock
JuBEMAnalysis.plot_smoothed
JuBEMAnalysis.plot_flexibility_matrix
JuBEMAnalysis.batch_plot_simulations
JuBEMAnalysis.save_figure
```
