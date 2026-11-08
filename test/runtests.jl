using JuBEMAnalysis
using Test
using HDF5
using MAT
using CairoMakie

@testset "JuBEMAnalysis.jl" begin

    @testset "Types & Coordinate Mapping" begin
        @test resolve_flex_coords(:NuzFz) == (1, 1)
        @test resolve_flex_coords(:Nz) == (1, 1)
        @test resolve_flex_coords(:NuxFx) == (2, 2)
        @test resolve_flex_coords(:NuyFy) == (3, 3)
        @test resolve_flex_coords(:NphizMz) == (4, 4)
        @test resolve_flex_coords(:NϕzMz) == (4, 4)
        @test resolve_flex_coords(:NphiyMy) == (5, 5)
        @test resolve_flex_coords(:NphixMx) == (6, 6)
        @test resolve_flex_coords((2, 6)) == (2, 6)
        @test resolve_flex_coords("NuxMy") == (2, 6)
        @test resolve_flex_coords("NphiyFx") == (5, 3)

        # Mock SimulationResult
        freqs = [1.0, 2.0, 3.0, 4.0, 5.0]
        N = zeros(ComplexF64, 5, 6, 6)
        for f in 1:5, i in 1:6, j in 1:6
            N[f, i, j] = (i + j) + im * (i * j * f)
        end
        sim = SimulationResult("mock.h5", "mock.h5", "Mock Simulation", freqs, N, nothing, nothing, Dict(:nelem => 100, :nelemt => 80))
        @test sim.label == "Mock Simulation"
        @test length(sim.freqs) == 5
        @test sim.metadata[:nelemt] == 80
    end

    @testset "Processing & Physics" begin
        # Soil on Bedrock analytical modes
        c_p = p_wave_speed(1.0, 0.3, 1.0)
        c_s = s_wave_speed(1.0, 1.0)
        @test c_p > c_s > 0

        modes = soil_on_bedrock_modes(4.0, 5; G=1.0, nu=0.3, rho=1.0, wave_type=:p_wave)
        @test length(modes) == 5
        @test issorted(modes)
        @test modes[1] ≈ c_p * (1) * pi / (2 * 4.0)

        # Flexibility extraction & difference
        freqs = collect(1.0:1.0:10.0)
        N = zeros(ComplexF64, 10, 6, 6)
        for f in 1:10
            N[f, 1, 1] = f + 2im * f
            N[f, 2, 6] = 2.0 * f + im * f
            N[f, 5, 3] = 2.0 * f + im * f
        end
        sim = SimulationResult("test.h5", "test.h5", "Test Sim", freqs, N, nothing, nothing, Dict{Symbol, Any}())

        d_uz = get_flexibility(sim, :NuzFz)
        @test length(d_uz) == 10
        @test d_uz[1] == 1.0 + 2.0im

        diff_cross = get_cross_difference(sim, :NuxMy, :NphiyFx)
        @test all(isapprox.(diff_cross, 0.0, atol=1e-12))

        # LOESS smoothing
        f_smooth, s_data = smooth_component(freqs, d_uz; span=0.3, n_resample=50)
        @test length(f_smooth) == 50
        @test length(s_data) == 50
        @test isapprox(real(s_data[1]), 1.0, atol=0.5)

        # Simulation smoothing
        f_all, sm_dict = smooth_simulation(sim; span=0.3, n_resample=20)
        @test length(f_all) == 20
        @test haskey(sm_dict, "NuzFz")
        @test haskey(sm_dict, "NuxMy")
    end

    @testset "IO & Exporting" begin
        mktempdir() do tmpdir
            # Create synthetic HDF5 file formatted like JuBEM output
            h5_path = joinpath(tmpdir, "test_sim.h5")
            freqs = [2.0, 4.0, 6.0, 8.0]
            fid = h5open(h5_path, "w")
            for f in freqs
                grp = create_group(fid, "freq_$(f)")
                write(grp, "N", ones(ComplexF64, 6, 6) .* f)
            end
            close(fid)

            # Load simulation
            sim = load_simulation(h5_path; label="Temp Sim", load_mesh=false)
            @test sim.label == "Temp Sim"
            @test sim.freqs == freqs
            @test size(sim.N) == (4, 6, 6)

            # Export to CSV
            csv_path = joinpath(tmpdir, "test.csv")
            export_csv(sim, csv_path)
            @test isfile(csv_path)
            lines = readlines(csv_path)
            @test startswith(lines[1], "frequency_hz")
            @test length(lines) == 5 # 1 header + 4 frequencies

            # Export to MAT
            mat_path = joinpath(tmpdir, "test.mat")
            export_mat(sim, mat_path)
            @test isfile(mat_path)
            mat = matopen(mat_path, "r")
            @test haskey(read(mat), "freqs")
            @test haskey(read(mat), "N_real")
            close(mat)

            # Export smoothed CSV
            sm_csv = joinpath(tmpdir, "smoothed.csv")
            _, sm_dict = smooth_simulation(sim; n_resample=10)
            export_smoothed_csv(sm_csv, 1:10, sm_dict)
            @test isfile(sm_csv)
        end
    end

    @testset "Plotting (CairoMakie)" begin
        mktempdir() do tmpdir
            freqs = collect(1.0:1.0:10.0)
            N = zeros(ComplexF64, 10, 6, 6)
            for f in 1:10, i in 1:6, j in 1:6
                N[f, i, j] = (i + j) / f + im * (sin(f) * i)
            end
            sim1 = SimulationResult("sim1.h5", "sim1.h5", "Sim 1", freqs, N, nothing, nothing, Dict(:nelemt => 100, :h => 8.0))
            sim2 = SimulationResult("sim2.h5", "sim2.h5", "Sim 2", freqs, N .* 1.05, nothing, nothing, Dict(:nelemt => 140, :h => 8.0))

            # 1. Single flexibility plot
            fig1 = plot_flexibility(sim1, :NuzFz; show_real=true, show_neg_imag=true, show_abs=true)
            @test fig1 isa Figure
            save_figure(fig1, joinpath(tmpdir, "flex.png"))
            @test isfile(joinpath(tmpdir, "flex.png"))

            # 2. Cross coupling plot
            fig2 = plot_cross_coupling(sim1, :NuxMy, :NphiyFx)
            @test fig2 isa Figure

            # 3. Multi-sim comparison plot
            fig3 = plot_simulations_comparison([sim1, sim2], :NuzFz; part=:abs)
            @test fig3 isa Figure

            # 4. Soil on bedrock plot
            fig4 = plot_soil_on_bedrock(sim1, :NuzFz)
            @test fig4 isa Figure

            # 5. Smoothed plot
            fig5 = plot_smoothed(sim1, :NuzFz; span=0.2)
            @test fig5 isa Figure

            # 6. Matrix overview
            fig6 = plot_flexibility_matrix(sim1)
            @test fig6 isa Figure

            # 7. Batch runner
            batch_plot_simulations([sim1, sim2], joinpath(tmpdir, "batch_out"))
            @test isdir(joinpath(tmpdir, "batch_out", "Sim 1"))
            @test isdir(joinpath(tmpdir, "batch_out", "comparisons"))
            @test isfile(joinpath(tmpdir, "batch_out", "Sim 1", "flexibility_matrix.png"))
            @test isfile(joinpath(tmpdir, "batch_out", "comparisons", "compare_NuzFz_abs.png"))
        end
    end
end
