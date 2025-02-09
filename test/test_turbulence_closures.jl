using Oceananigans.Diagnostics

for closure in closures
    @eval begin
        using Oceananigans.TurbulenceClosures: $closure
    end
end

function closure_instantiation(closurename)
    closure = getproperty(TurbulenceClosures, closurename)()
    return true
end

function constant_isotropic_diffusivity_basic(T=Float64; ν=T(0.3), κ=T(0.7))
    closure = IsotropicDiffusivity(T; κ=(T=κ, S=κ), ν=ν)
    return closure.ν == ν && closure.κ.T == κ
end

function anisotropic_diffusivity_convenience_kwarg(T=Float64; νh=T(0.3), κh=T(0.7))
    closure = AnisotropicDiffusivity(κh=(T=κh, S=κh), νh=νh)
    return closure.νx == νh && closure.νy == νh && closure.κy.T == κh && closure.κx.T == κh
end

function constant_isotropic_diffusivity_fluxdiv(FT=Float64; ν=FT(0.3), κ=FT(0.7))
          arch = CPU()
       closure = IsotropicDiffusivity(FT, κ=(T=κ, S=κ), ν=ν)
          grid = RegularCartesianGrid(FT, size=(3, 1, 4), extent=(3, 1, 4))
    velocities = VelocityFields(arch, grid)
       tracers = TracerFields(arch, grid, (:T, :S))
         clock = Clock(time=0.0)

    u, v, w = velocities
       T, S = tracers

    for k in 1:4
        interior(u)[:, 1, k] .= [0, -1, 0]
        interior(v)[:, 1, k] .= [0, -2, 0]
        interior(w)[:, 1, k] .= [0, -3, 0]
        interior(T)[:, 1, k] .= [0, -1, 0]
    end

    state = (velocities=datatuple(velocities), tracers=datatuple(tracers), diffusivities=nothing)
    fill_halo_regions!(merge(velocities, tracers), arch, nothing, state)

    U, C = datatuples(velocities, tracers)

    return (   ∇_κ_∇c(2, 1, 3, grid, clock, closure, C.T, Val(1)) == 2κ &&
            ∂ⱼ_2ν_Σ₁ⱼ(2, 1, 3, grid, clock, closure, U) == 2ν &&
            ∂ⱼ_2ν_Σ₂ⱼ(2, 1, 3, grid, clock, closure, U) == 4ν &&
            ∂ⱼ_2ν_Σ₃ⱼ(2, 1, 3, grid, clock, closure, U) == 6ν )
end

function anisotropic_diffusivity_fluxdiv(FT=Float64; νh=FT(0.3), κh=FT(0.7), νz=FT(0.1), κz=FT(0.5))
          arch = CPU()
       closure = AnisotropicDiffusivity(FT, νh=νh, νz=νz, κh=(T=κh, S=κh), κz=(T=κz, S=κz))
          grid = RegularCartesianGrid(FT, size=(3, 1, 4), extent=(3, 1, 4))
           eos = LinearEquationOfState(FT)
      buoyancy = SeawaterBuoyancy(FT, gravitational_acceleration=1, equation_of_state=eos)
    velocities = VelocityFields(arch, grid)
       tracers = TracerFields(arch, grid, (:T, :S))
         clock = Clock(time=0.0)

    u, v, w, T, S = merge(velocities, tracers)

    interior(u)[:, 1, 2] .= [0,  1, 0]
    interior(u)[:, 1, 3] .= [0, -1, 0]
    interior(u)[:, 1, 4] .= [0,  1, 0]

    interior(v)[:, 1, 2] .= [0,  1, 0]
    interior(v)[:, 1, 3] .= [0, -2, 0]
    interior(v)[:, 1, 4] .= [0,  1, 0]

    interior(w)[:, 1, 2] .= [0,  1, 0]
    interior(w)[:, 1, 3] .= [0, -3, 0]
    interior(w)[:, 1, 4] .= [0,  1, 0]

    interior(T)[:, 1, 2] .= [0,  1, 0]
    interior(T)[:, 1, 3] .= [0, -4, 0]
    interior(T)[:, 1, 4] .= [0,  1, 0]

    state = (velocities=datatuple(velocities), tracers=datatuple(tracers), diffusivities=nothing)
    fill_halo_regions!(merge(velocities, tracers), arch, nothing, state)

    U, C = datatuples(velocities, tracers)

    return (   ∇_κ_∇c(2, 1, 3, grid, clock, closure, C.T, Val(1)) == 8κh + 10κz &&
            ∂ⱼ_2ν_Σ₁ⱼ(2, 1, 3, grid, clock, closure, U) == 2νh + 4νz &&
            ∂ⱼ_2ν_Σ₂ⱼ(2, 1, 3, grid, clock, closure, U) == 4νh + 6νz &&
            ∂ⱼ_2ν_Σ₃ⱼ(2, 1, 3, grid, clock, closure, U) == 6νh + 8νz)
end

function test_calculate_diffusivities(arch, closurename, FT=Float64; kwargs...)
      tracernames = (:b,)
          closure = getproperty(TurbulenceClosures, closurename)(FT, kwargs...)
          closure = with_tracers(tracernames, closure)
             grid = RegularCartesianGrid(FT, size=(3, 3, 3), extent=(3, 3, 3))
    diffusivities = DiffusivityFields(arch, grid, tracernames, closure)
         buoyancy = BuoyancyTracer()
       velocities = VelocityFields(arch, grid)
          tracers = TracerFields(arch, grid, tracernames)

    U, C, K = datatuples(velocities, tracers, diffusivities)
    calculate_diffusivities!(K, arch, grid, closure, buoyancy, U, C)

    return true
end

function time_step_with_variable_isotropic_diffusivity(arch)

    closure = IsotropicDiffusivity(ν = (x, y, z, t) -> exp(z) * cos(x) * cos(y) * cos(t),
                                   κ = (x, y, z, t) -> exp(z) * cos(x) * cos(y) * cos(t))

    model = IncompressibleModel(
        architecture=arch, closure=closure,
        grid=RegularCartesianGrid(size=(1, 1, 1), extent=(1, 2, 3))
    )

    time_step!(model, 1, euler=true)

    return true
end

function time_step_with_variable_anisotropic_diffusivity(arch)

    closure = AnisotropicDiffusivity(
                                     νx = (x, y, z, t) -> 1 * exp(z) * cos(x) * cos(y) * cos(t),
                                     νy = (x, y, z, t) -> 2 * exp(z) * cos(x) * cos(y) * cos(t),
                                     νz = (x, y, z, t) -> 4 * exp(z) * cos(x) * cos(y) * cos(t),
                                     κx = (x, y, z, t) -> 1 * exp(z) * cos(x) * cos(y) * cos(t),
                                     κy = (x, y, z, t) -> 2 * exp(z) * cos(x) * cos(y) * cos(t),
                                     κz = (x, y, z, t) -> 4 * exp(z) * cos(x) * cos(y) * cos(t)
                                    )

    model = IncompressibleModel(
        architecture=arch, closure=closure,
        grid=RegularCartesianGrid(size=(1, 1, 1), extent=(1, 2, 3))
    )

    time_step!(model, 1, euler=true)

    return true
end

function time_step_with_tupled_closure(FT, arch)
    closure_tuple = (AnisotropicMinimumDissipation(FT), AnisotropicDiffusivity(FT))

    model = IncompressibleModel(
        architecture=arch, float_type=FT, closure=closure_tuple,
        grid=RegularCartesianGrid(FT, size=(1, 1, 1), extent=(1, 2, 3))
    )

    time_step!(model, 1, euler=true)
    return true
end

function compute_closure_specific_diffusive_cfl(closurename)
    grid = RegularCartesianGrid(size=(1, 1, 1), extent=(1, 2, 3))
    closure = getproperty(TurbulenceClosures, closurename)()

    model = IncompressibleModel(grid=grid, closure=closure)
    dcfl = DiffusiveCFL(0.1)
    @test dcfl(model) isa Number

    tracerless_model = IncompressibleModel(grid=grid, closure=closure,
                                           buoyancy=nothing, tracers=nothing)
    dcfl = DiffusiveCFL(0.2)
    @test dcfl(tracerless_model) isa Number

    return nothing
end

@testset "Turbulence closures" begin
    @info "Testing turbulence closures..."

    @testset "Closure instantiation" begin
        @info "  Testing closure instantiation..."
        for closure in closures
            @test closure_instantiation(closure)
        end
    end

    @testset "Constant isotropic diffusivity" begin
        @info "  Testing constant isotropic diffusivity..."
        for T in float_types
            @test constant_isotropic_diffusivity_basic(T)
            @test constant_isotropic_diffusivity_fluxdiv(T)
        end
    end

    @testset "Constant anisotropic diffusivity" begin
        @info "  Testing constant anisotropic diffusivity..."
        for T in float_types
            @test anisotropic_diffusivity_convenience_kwarg(T)
            @test anisotropic_diffusivity_fluxdiv(T, νz=zero(T), νh=zero(T))
            @test anisotropic_diffusivity_fluxdiv(T)
        end
    end

    @testset "Time-stepping with variable diffusivities" begin
        @info "  Testing time-stepping with presribed variable diffusivities..."
        for arch in archs
            @test time_step_with_variable_isotropic_diffusivity(arch)
            @test time_step_with_variable_anisotropic_diffusivity(arch)
        end
    end

    @testset "Calculation of nonlinear diffusivities" begin
        @info "  Testing calculation of nonlinear diffusivities..."
        for FT in [Float64]
            for arch in archs
                for closure in closures
                    @info "    Calculating diffusivities for $closure [$FT, $(typeof(arch))]"
                    @test test_calculate_diffusivities(arch, closure, FT)
                end
            end
        end
    end

    @testset "Closure tuples" begin
        @info "  Testing time-stepping with a tuple of closures..."
        for arch in archs
            for FT in float_types
                @test time_step_with_tupled_closure(FT, arch)
            end
        end
    end

    @testset "Diagnostics" begin
        @info "  Testing turbulence closure diagnostics..."
        for closure in closures
            compute_closure_specific_diffusive_cfl(closure)
        end
    end
end
