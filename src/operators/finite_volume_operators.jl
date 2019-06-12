using Oceananigans:
    Grid, RegularCartesianGrid, VerticallyStretchedCartesianGrid

@inline Δx(i, j, k, grid::RegularCartesianGrid) = grid.Δx
@inline Δx(i, j, k, grid::VerticallyStretchedCartesianGrid) = grid.Δx
@inline Δx(i, j, k, grid::Grid) = @inbounds grid.Δx[i, j, k]

@inline Δy(i, j, k, grid::RegularCartesianGrid) = grid.Δy
@inline Δy(i, j, k, grid::VerticallyStretchedCartesianGrid) = grid.Δy
@inline Δy(i, j, k, grid::Grid) = @inbounds grid.Δy[i, j, k]

@inline Δz(i, j, k, grid::RegularCartesianGrid) = grid.Δz
@inline Δz(i, j, k, grid::VerticallyStretchedCartesianGrid) = @inbounds grid.Δz[k]
@inline Δz(i, j, k, grid::Grid) = @inbounds grid.Δz[i, j, k]

@inline Ax(i, j, k, grid::Grid) = Δy(i, j, k, grid) * Δz(i, j, k, grid)
@inline Ay(i, j, k, grid::Grid) = Δx(i, j, k, grid) * Δz(i, j, k, grid)
@inline Az(i, j, k, grid::Grid) = Δx(i, j, k, grid) * Δy(i, j, k, grid)

@inline V(i, j, k, grid::Grid) = Δx(i, j, k, grid) * Δy(i, j, k, grid) * Δz(i, j, k, grid)
@inline V⁻¹(i, j, k, grid::Grid) = 1 / V(i, j, k, grid)

@inline δx_caa(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i+1, j, k] - f[i,   j, k]
@inline δx_faa(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i,   j, k] - f[i-1, j, k]
# @inline δx_e2f(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i+1, j, k] - f[i,   j, k]
# @inline δx_f2e(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i,   j, k] - f[i-1, j, k]

@inline δy_aca(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i, j+1, k] - f[i, j,   k]
@inline δy_afa(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i, j,   k] - f[i, j-1, k]
# @inline δy_e2f(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i, j+1, k] - f[i, j,   k]
# @inline δy_f2e(i, j, k, grid::Grid, f::AbstractArray) = @inbounds f[i, j,   k] - f[i, j-1, k]

@inline function δz_aac(i, j, k, g::Grid{T}, f::AbstractArray) where T
    if k == grid.Nz
        @inbounds return f[i, j, k]
    else
        @inbounds return f[i, j, k] - f[i, j, k+1]
    end
end

@inline function δz_aaf(i, j, k, g::Grid{T}, f::AbstractArray) where T
    if k == 1
        return -zero(T)
    else
        @inbounds return f[i, j, k-1] - f[i, j, k]
    end
end

# @inline function δz_e2f(i, j, k, g::Grid{T}, f::AbstractArray) where T
#     if k == grid.Nz
#         @inbounds return f[i, j, k]
#     else
#         @inbounds return f[i, j, k] - f[i, j, k+1]
#     end
# end
#
# @inline function δz_f2e(i, j, k, g::Grid{T}, f::AbstractArray) where T
#     if k == 1
#         return -zero(T)
#     else
#         @inbounds return f[i, j, k-1] - f[i, j, k]
#     end
# end

@inline δxA_caa(i, j, k, grid::Grid, f::AbstractArray) = @inbounds Ax(i+1, j, k, grid) * f[i+1, j, k] - Ax(i,   j, k) * f[i,   j, k]
@inline δxA_faa(i, j, k, grid::Grid, f::AbstractArray) = @inbounds Ax(i,   j, k, grid) * f[i,   j, k] - Ax(i-1, j, k) * f[i-1, j, k]

@inline δyA_aca(i, j, k, grid::Grid, f::AbstractArray) = @inbounds Ay(i, j+1, k, grid) * f[i, j+1, k] - Ay(i, j,   k, grid) * f[i, j,   k]
@inline δyA_afa(i, j, k, grid::Grid, f::AbstractArray) = @inbounds Ay(i,   j, k, grid) * f[i, j,   k] - Ay(i, j-1, k, grid) * f[i, j-1, k]

@inline function δzA_aac(i, j, k, g::Grid{T}, f::AbstractArray) where T
    if k == grid.Nz
        @inbounds return Az(i, j, k, grid) * f[i, j, k]
    else
        @inbounds return Az(i, j, k, grid) * f[i, j, k] - Az(i, j, k+1, grid) * f[i, j, k+1]
    end
end

@inline function δzA_aaf(i, j, k, g::Grid{T}, f::AbstractArray) where T
    if k == 1
        return -zero(T)
    else
        @inbounds return Az(i, j, k-1, grid) * f[i, j, k-1] - Az(i, j, k, grid) * f[i, j, k]
    end
end

@inline ϊx_caa(i, j, k, grid::Grid{T}, f::AbstractArray) where T = @inbounds T(0.5) * (f[i+1, j, k] + f[i,    j, k])
@inline ϊx_faa(i, j, k, grid::Grid{T}, f::AbstractArray) where T = @inbounds T(0.5) * (f[i,   j, k] + f[i-1,  j, k])
# @inline ϊx_f2e(i, j, k, grid::Grid{T}, f::AbstractArray) where T = @inbounds T(0.5) * (f[i,   j, k] + f[i-1,  j, k])

@inline ϊy_aca(i, j, k, grid::Grid{T}, f::AbstractArray) where T = @inbounds T(0.5) * (f[i, j+1, k] + f[i,    j, k])
@inline ϊy_afa(i, j, k, grid::Grid{T}, f::AbstractArray) where T = @inbounds T(0.5) * (f[i,   j, k] + f[i,  j-1, k])
# @inline ϊy_f2e(i, j, k, grid::Grid{T}, f::AbstractArray) where T = @inbounds T(0.5) * (f[i,   j, k] + f[i,  j-1, k])

@inline fv(i, j, k, grid::Grid{T}, v::AbstractArray, f::AbstractFloat) where T = T(0.5) * f * (avgy_aca(i-1,  j, k, grid, v) + avgy_aca(i, j, k, grid, v))
@inline fu(i, j, k, grid::Grid{T}, u::AbstractArray, f::AbstractFloat) where T = T(0.5) * f * (avgx_caa(i,  j-1, k, grid, u) + avgx_caa(i, j, k, grid, u))

@inline function ϊz_aac(i, j, k, grid::Grid{T}, f::AbstractArray) where T
    if k == grid.Nz
        @inbounds return T(0.5) * f[i, j, k]
    else
        @inbounds return T(0.5) * (f[i, j, k+1] + f[i, j, k])
    end
end

@inline function ϊz_aaf(i, j, k, grid::Grid{T}, f::AbstractArray) where T
    if k == 1
        @inbounds return f[i, j, k]
    else
        @inbounds return T(0.5) * (f[i, j, k] + f[i, j, k-1])
    end
end

# @inline function ϊz_f2e(i, j, k, grid::Grid{T}, f::AbstractArray) where T
#     if k == 1
#         @inbounds return f[i, j, k]
#     else
#         @inbounds return T(0.5) * (f[i, j, k] + f[i, j, k-1])
#     end
# end

@inline function div_ccc(i, j, k, grid::Grid, fx::AbstractArray, fy::AbstractArray, fz::AbstractArray)
    V⁻¹(i, j, k, grid) * (δxA_caa(i, j, k, grid, fx) + δyA_aca(i, j, k, grid, fy) + δzA_aac(i, j, k, grid, fz))
end

@inline function δxA_caa_ab̄ˣ(i, j, k, grid::Grid, a::AbstractArray, b::AbstractArray)
    @inbounds (Ax(i, j, k, grid) * a[i+1, j, k] * ϊx_faa(i+1, j, k, grid, b) -
               Ax(i, j, k, grid) * a[i,   j, k] * ϊx_faa(i,   j, k, grid, b))
end

@inline function δy_aca_ab̄ʸ(i, j, k, grid::Grid, a::AbstractArray, b::AbstractArray)
    @inbounds (Ay(i, j, k, grid) * a[i, j+1, k] * ϊy_afa(i, j+1, k, grid, b) -
               Ay(i, j, k, grid) * a[i,   j, k] * ϊy_afa(i, j,   k, grid, b))
end

@inline function δz_aac_ab̄ᶻ(i, j, k, grid::Grid, a::AbstractArray, b::AbstractArray)
    if k == grid.Nz
        @inbounds return Az(i, j, k, grid) * a[i, j, k] * ϊz_aaf(i, j, k, grid, b)
    else
        @inbounds return (Az(i, j, k, grid) * a[i, j,   k] * ϊz_aaf(i, j,   k, grid, b) -
                          Az(i, j, k, grid) * a[i, j, k+1] * ϊz_aaf(i, j, k+1, grid, b))
    end
end

@inline function div_flux(i, j, k, grid::Grid, u::AbstractArray, v::AbstractArray, w::AbstractArray, Q::AbstractArray)
    if k == 1
        @inbounds return V⁻¹(i, j, k, grid) * (δxA_caa_ab̄ˣ(i, j, k, grid, u, Q) + δyA_aca_ab̄ʸ(i, j, k, grid, v, Q) - Az(i, j, k, grid) * (w[i, j, 2] * ϊz_aaf(i, j, 2, grid, Q))
    else
        return V⁻¹(i, j, k, grid) * (δxA_caa_ab̄ˣ(i, j, k, grid, u, Q) + δyA_aca_ab̄ʸ(i, j, k, grid, v, Q) + δzA_aac_ab̄ᶻ(i, j, k, grid, w, Q))
    end
end

@inline function δxA_faa_ūˣūˣ(i, j, k, g::Grid, u::AbstractArray)
    avgx_f2c(i, j, k, grid, u)^2 - avgx_f2c(i-1, j, k, grid, u)^2
end

@inline function δy_e2f_v̄ˣūʸ(g::RegularCartesianGrid, u, v, i, j, k)
    avgx_f2e(g, v, i, j+1, k) * avgy_f2e(g, u, i, j+1, k) -
    avgx_f2e(g, v, i,   j, k) * avgy_f2e(g, u, i,   j, k)
end

@inline function δz_e2f_w̄ˣūᶻ(g::RegularCartesianGrid, u, w, i, j, k)
    if k == g.Nz
        @inbounds return avgx_f2e(g, w, i, j, k) * avgz_f2e(g, u, i, j, k)
    else
        @inbounds return avgx_f2e(g, w, i, j,   k) * avgz_f2e(g, u, i, j,   k) -
                         avgx_f2e(g, w, i, j, k+1) * avgz_f2e(g, u, i, j, k+1)
    end
end

@inline function u∇u(g::RegularCartesianGrid, u, v, w, i, j, k)
    (δx_c2f_ūˣūˣ(g, u, i, j, k) / g.Δx) + (δy_e2f_v̄ˣūʸ(g, u, v, i, j, k) / g.Δy) + (δz_e2f_w̄ˣūᶻ(g, u, w, i, j, k) / g.Δz)
end
