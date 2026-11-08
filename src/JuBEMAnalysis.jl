module JuBEMAnalysis

include("types.jl")
include("processing.jl")
include("io.jl")
include("plotting.jl")

# Re-export submodules
using .Types
using .Processing
using .IO
using .Plotting

# Re-export Types
export SimulationResult, DOF_MAP, FLEX_INDEX_MAP, resolve_flex_coords

# Re-export IO
export load_simulation, load_simulations, export_csv, export_mat, export_smoothed_csv

# Re-export Processing
export get_flexibility, get_cross_difference, smooth_component, smooth_simulation,
       soil_on_bedrock_modes, p_wave_speed, s_wave_speed

# Re-export Plotting
export plot_flexibility, plot_flexibility_matrix, plot_simulations_comparison,
       plot_cross_coupling, plot_soil_on_bedrock, plot_smoothed, batch_plot_simulations,
       save_figure

end # module JuBEMAnalysis
