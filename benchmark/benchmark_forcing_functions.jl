using Printf
using TimerOutputs
using Oceananigans
using Oceananigans.Utils

include("benchmark_utils.jl")

#####
##### Benchmark setup and parameters
#####

const timer = TimerOutput()

Ni = 2   # Number of iterations before benchmarking starts.
Nt = 10  # Number of iterations to use for benchmarking time stepping.

# Run benchmark across these parameters.
            Ns = [(128, 128, 128)]
   float_types = [Float64]  # Float types to benchmark.
         archs = [CPU()]    # Architectures to benchmark on.
@hascuda archs = [GPU()]    # Benchmark GPU on systems with CUDA-enabled GPUs.

#####
##### Forcing function definitions
#####

@inline function Fu_params(i, j, k, grid, time, U, C, params)
    if k == 1
        return @inbounds -2*params.K/grid.Δz^2 * (U.u[i, j, 1] - 0)
    elseif k == grid.Nz
        return @inbounds -2*params.K/grid.Δz^2 * (U.u[i, j, grid.Nz] - 0)
    else
        return 0
    end
end

const K = 0.1
@inline function Fu_consts(i, j, k, grid, time, U, C, params)
    if k == 1
        return @inbounds -2*K/grid.Δz^2 * (U.u[i, j, 1] - 0)
    elseif k == grid.Nz
        return @inbounds -2*K/grid.Δz^2 * (U.u[i, j, grid.Nz] - 0)
    else
        return 0
    end
end

@inline FT_params(i, j, k, grid, time, U, C, params) = @inbounds ifelse(k == 1, -params.λ * (C.T[i, j, 1] - 0), 0)

const λ = 1e-4
@inline FT_consts(i, j, k, grid, time, U, C, params) = @inbounds ifelse(k == 1, -λ * (C.T[i, j, 1] - 0), 0)

#####
##### Run benchmarks
#####

for arch in archs, FT in float_types, N in Ns
    Nx, Ny, Nz = N
    Lx, Ly, Lz = 1, 1, 1

    forced_model_params = Model(architecture = arch, float_type = FT,
		                grid = RegularCartesianGrid(size=(Nx, Ny, Nz), extent=(Lx, Ly, Lz)),
                                forcing=ModelForcing(Fu=Fu_params, FT=FT_params), parameters=(K=0.1, λ=1e-4))

    time_step!(forced_model_params, Ni, 1)  # First 1-2 iterations usually slower.

    bn =  benchmark_name(N, "with forcing (params)", arch, FT)
    @printf("Running benchmark: %s...\n", bn)
    for i in 1:Nt
        @timeit timer bn time_step!(forced_model_params, 1, 1)
    end

    forced_model_consts = Model(architecture = arch, float_type = FT,
		                grid = RegularCartesianGrid(size=(Nx, Ny, Nz), extent=(Lx, Ly, Lz)),
                                forcing=ModelForcing(Fu=Fu_consts, FT=FT_consts))

    time_step!(forced_model_consts, Ni, 1)  # First 1-2 iterations usually slower.

    bn =  benchmark_name(N, "with forcing (consts)", arch, FT)
    @printf("Running benchmark: %s...\n", bn)
    for i in 1:Nt
        @timeit timer bn time_step!(forced_model_consts, 1, 1)
    end

    unforced_model = Model(architecture = arch, float_type = FT,
			   grid = RegularCartesianGrid(size=(Nx, Ny, Nz), extent=(Lx, Ly, Lz)))

    time_step!(unforced_model, Ni, 1)  # First 1-2 iterations usually slower.

    bn =  benchmark_name(N, "  no forcing         ", arch, FT)
    @printf("Running benchmark: %s...\n", bn)
    for i in 1:Nt
        @timeit timer bn time_step!(unforced_model, 1, 1)
    end
end

#####
##### Print benchmark results
#####

println()
print(versioninfo_with_gpu())
print_timer(timer, title="Forcing function benchmarks")
println()
