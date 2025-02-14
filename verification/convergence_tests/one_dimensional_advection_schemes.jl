using Test

using PyPlot
using LaTeXStrings

using Oceananigans.Advection

# Define a few utilities for running tests and unpacking and plotting results
include("ConvergenceTests/ConvergenceTests.jl")

using .ConvergenceTests
using .ConvergenceTests.OneDimensionalGaussianAdvectionDiffusion: run_test
using .ConvergenceTests.OneDimensionalUtils: unpack_errors, defaultcolors, removespines

""" Run advection test for all Nx in resolutions. """
function run_convergence_test(κ, U, resolutions, advection_scheme)

    # Determine safe time-step
           Lx = 2.5
    stop_time = 1e-3
            h = Lx / maximum(resolutions)
           Δt = min(1e-2 * h / U, 1e-3 * h^2 / κ)

    # Run the tests
    results = [run_test(Nx=Nx, Δt=Δt, advection=advection_scheme, stop_iteration=1,
                        U=U, κ=κ) for Nx in resolutions]

    return results
end

#####
##### Run test
#####

advection_schemes = (CenteredSecondOrder(), CenteredFourthOrder(), UpwindBiasedThirdOrder(), WENO5())

U = -3
κ = 1e-8
Nx = 2 .^ (7:10)

results = Dict()
for scheme in advection_schemes
    t_scheme = typeof(scheme)
    results[t_scheme] = run_convergence_test(κ, U, Nx, scheme)
end

rate_of_convergence(::CenteredSecondOrder) = 2
rate_of_convergence(::CenteredFourthOrder) = 4
rate_of_convergence(::UpwindBiasedThirdOrder) = 3
rate_of_convergence(::WENO5) = 5
rate_of_convergence(::WENO{K}) where K = 2K-1

fig, ax = subplots()

@testset "tmp" begin
for (j, scheme) in enumerate(advection_schemes)
    t_scheme = typeof(scheme)
    name = string(t_scheme)
    roc = rate_of_convergence(scheme)
    
    u_L₁, v_L₁, cx_L₁, cy_L₁, u_L∞, v_L∞, cx_L∞, cy_L∞ = unpack_errors(results[typeof(scheme)])

    atol = t_scheme == CenteredSecondOrder ? 0.05 :
           t_scheme == CenteredFourthOrder ? 0.12 :
           t_scheme == WENO5               ? 0.40 : Inf

    test_rate_of_convergence(u_L₁,  Nx, expected=-roc, atol=atol, name=name*" u_L₁")
    test_rate_of_convergence(v_L₁,  Nx, expected=-roc, atol=atol, name=name*" v_L₁")
    test_rate_of_convergence(cx_L₁, Nx, expected=-roc, atol=atol, name=name*" cx_L₁")
    test_rate_of_convergence(cy_L₁, Nx, expected=-roc, atol=atol, name=name*" cy_L₁")
    test_rate_of_convergence(u_L∞,  Nx, expected=-roc, atol=atol, name=name*" u_L∞")
    test_rate_of_convergence(v_L∞,  Nx, expected=-roc, atol=atol, name=name*" v_L∞")
    test_rate_of_convergence(cx_L∞, Nx, expected=-roc, atol=atol, name=name*" cx_L∞")
    test_rate_of_convergence(cy_L∞, Nx, expected=-roc, atol=atol, name=name*" cy_L∞")

    @test  u_L₁ ≈  v_L₁
    @test cx_L₁ ≈ cy_L₁
    @test  u_L∞ ≈  v_L∞
    @test cx_L∞ ≈ cy_L∞

    common_kwargs = (linestyle="None", color=defaultcolors[j], mfc="None", alpha=0.8)
    loglog(Nx,  u_L₁; basex=2, marker="o", label="\$L_1\$-norm, \$u\$ $name", common_kwargs...)
    loglog(Nx,  v_L₁; basex=2, marker="2", label="\$L_1\$-norm, \$v\$ $name", common_kwargs...)
    loglog(Nx, cx_L₁; basex=2, marker="*", label="\$L_1\$-norm, \$x\$ tracer $name", common_kwargs...)
    loglog(Nx, cy_L₁; basex=2, marker="+", label="\$L_1\$-norm, \$y\$ tracer $name", common_kwargs...)

    loglog(Nx,  u_L∞; basex=2, marker="1", label="\$L_\\infty\$-norm, \$u\$ $name", common_kwargs...)
    loglog(Nx,  v_L∞; basex=2, marker="_", label="\$L_\\infty\$-norm, \$v\$ $name", common_kwargs...)
    loglog(Nx, cx_L∞; basex=2, marker="^", label="\$L_\\infty\$-norm, \$x\$ tracer $name", common_kwargs...)
    loglog(Nx, cy_L∞; basex=2, marker="s", label="\$L_\\infty\$-norm, \$y\$ tracer $name", common_kwargs...)

    label = raw"\sim N_x^{-" * "$roc" * raw"}" |> latexstring
    loglog(Nx, cx_L₁[1] .* (Nx[1] ./ Nx) .^ roc, color=defaultcolors[j], basex=2, alpha=0.8, label=label)

    xlabel(L"N_x")
    ylabel("\$L\$-norms of \$ | c_\\mathrm{sim} - c_\\mathrm{analytical} |\$")
    removespines("top", "right")
    lgd = legend(loc="upper right", bbox_to_anchor=(1.4, 1.0), prop=Dict(:size=>6))

    if j == length(advection_schemes)
        filepath = joinpath(@__DIR__, "figs", "one_dimensional_convergence.png")
        savefig(filepath, dpi=480, bbox_extra_artists=(lgd,), bbox_inches="tight")
        close(fig)
    end
end
end
