function run_thermal_bubble_regression_test(arch)
    Nx, Ny, Nz = 16, 16, 16
    Lx, Ly, Lz = 100, 100, 100
    Δt = 6

    grid = RegularCartesianGrid(size=(Nx, Ny, Nz), extent=(Lx, Ly, Lz))
    closure = IsotropicDiffusivity(ν=4e-2, κ=4e-2)
    model = IncompressibleModel(architecture=arch, grid=grid, closure=closure, coriolis=FPlane(f=1e-4))
    simulation = Simulation(model, Δt=6, stop_iteration=10)

    model.tracers.T.data.parent .= 9.85
    model.tracers.S.data.parent .= 35.0

    # Add a cube-shaped warm temperature anomaly that takes up the middle 50%
    # of the domain volume.
    i1, i2 = round(Int, Nx/4), round(Int, 3Nx/4)
    j1, j2 = round(Int, Ny/4), round(Int, 3Ny/4)
    k1, k2 = round(Int, Nz/4), round(Int, 3Nz/4)
    model.tracers.T.data[i1:i2, j1:j2, k1:k2] .+= 0.01

    regression_data_filepath = joinpath(dirname(@__FILE__), "data", "thermal_bubble_regression.nc")

    ####
    #### Uncomment the block below to generate regression data.
    ####

    #=
    @warn ("You are generating new data for the thermal bubble regression test.")

    outputs = Dict("v" => model.velocities.v,
                   "u" => model.velocities.u,
                   "w" => model.velocities.w,
                   "T" => model.tracers.T,
                   "S" => model.tracers.S)

    nc_writer = NetCDFOutputWriter(model, outputs, filename=regression_data_filepath, iteration_interval=10)
    push!(simulation.output_writers, nc_writer)
    =#

    ####
    #### Regression test
    ####

    run!(simulation)

    ds = Dataset(regression_data_filepath, "r")

    test_fields = (u = Array(interior(model.velocities.u)),
                   v = Array(interior(model.velocities.v)),
                   w = Array(interior(model.velocities.w)),
                   T = Array(interior(model.tracers.T)),
                   S = Array(interior(model.tracers.S)))

    correct_fields = (u = ds["u"][:, :, :, end],
                      v = ds["v"][:, :, :, end],
                      w = ds["w"][:, :, :, end],
                      T = ds["T"][:, :, :, end],
                      S = ds["S"][:, :, :, end])

    summarize_regression_test(test_fields, correct_fields)

    @test all(test_fields.u .≈ correct_fields.u)
    @test all(test_fields.v .≈ correct_fields.v)
    @test all(test_fields.w .≈ correct_fields.w)
    @test all(test_fields.T .≈ correct_fields.T)
    @test all(test_fields.S .≈ correct_fields.S)

    return nothing
end
