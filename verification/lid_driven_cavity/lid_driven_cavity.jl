using Printf
using Logging

using Oceananigans
using Oceananigans: Face, Cell
using Oceananigans.Diagnostics
using Oceananigans.OutputWriters
using Oceananigans.AbstractOperations

Logging.global_logger(OceananigansLogger())

function simulate_lid_driven_cavity(; Re, N, end_time)
    topology = (Flat, Bounded, Bounded)
    domain = (x=(0, 1), y=(0, 1), z=(0, 1))
    grid = RegularCartesianGrid(topology=topology, size=(1, N, N); domain...)

    v_bcs = VVelocityBoundaryConditions(grid,
           top = ValueBoundaryCondition(1.0),
        bottom = ValueBoundaryCondition(0.0)
    )

    w_bcs = WVelocityBoundaryConditions(grid,
        north = ValueBoundaryCondition(0.0),
        south = ValueBoundaryCondition(0.0)
    )

    model = IncompressibleModel(
                       grid = grid,
                   buoyancy = nothing,
                    tracers = nothing,
                   coriolis = nothing,
        boundary_conditions = (v=v_bcs, w=w_bcs),
                    closure = IsotropicDiffusivity(ν=1/Re)
    )

    u, v, w = model.velocities
    ζ_op = ∂y(w) - ∂z(v)
    ζ = Field(Cell, Face, Face, model.architecture, model.grid, TracerBoundaryConditions(grid))
    ζ_computation = Computation(ζ_op, ζ)

    fields = Dict(
        "v" => model.velocities.v,
        "w" => model.velocities.w,
        "ζ" => model -> ζ_computation(model)
    )

    dims = Dict("ζ" => ("xC", "yF", "zF"))
    global_attributes = Dict("Re" => Re)
    output_attributes = Dict("ζ" => Dict("longname" => "vorticity", "units" => "1/s"))

    field_output_writer =
        NetCDFOutputWriter(model, fields, filename="lid_driven_cavity_Re$Re.nc", time_interval=0.1,
                           global_attributes=global_attributes, output_attributes=output_attributes,
                           dimensions=dims)

    max_Δt = 0.25 * model.grid.Δy^2 * Re / 2  # Make sure not to violate diffusive CFL.
    wizard = TimeStepWizard(cfl=0.1, Δt=1e-6, max_change=1.1, max_Δt=max_Δt)

    cfl = AdvectiveCFL(wizard)
    dcfl = DiffusiveCFL(wizard)

    simulation = Simulation(model, Δt=wizard, stop_time=end_time, progress=print_progress,
                            iteration_interval=20, parameters=(cfl=cfl, dcfl=dcfl))

    simulation.output_writers[:fields] = field_output_writer

    run!(simulation)

    return simulation
end

function print_progress(simulation)
    model = simulation.model
    cfl, dcfl = simulation.parameters

    # Calculate simulation progress in %.
    progress = 100 * (model.clock.time / simulation.stop_time)

    # Find maximum velocities.
    vmax = maximum(abs, interior(model.velocities.v))
    wmax = maximum(abs, interior(model.velocities.w))

    i, t = model.clock.iteration, model.clock.time
    @info @sprintf("[%06.2f%%] i: %d, t: %.3f, U_max: (%.2e, %.2e), CFL: %.2e, dCFL: %.2e, next Δt: %.2e",
                   progress, i, t, vmax, wmax, cfl(model), dcfl(model), simulation.Δt.Δt)

    return nothing
end

 simulate_lid_driven_cavity(Re=100,   N=128, end_time=15)
 simulate_lid_driven_cavity(Re=400,   N=128, end_time=20)
 simulate_lid_driven_cavity(Re=1000,  N=128, end_time=25)
 simulate_lid_driven_cavity(Re=3200,  N=128, end_time=50)
 simulate_lid_driven_cavity(Re=5000,  N=256, end_time=50)
 simulate_lid_driven_cavity(Re=7500,  N=256, end_time=75)
 simulate_lid_driven_cavity(Re=10000, N=256, end_time=100)

