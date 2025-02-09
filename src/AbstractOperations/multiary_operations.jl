const multiary_operators = Set()

struct MultiaryOperation{X, Y, Z, N, O, A, I, G} <: AbstractOperation{X, Y, Z, G}
      op :: O
    args :: A
       ▶ :: I
    grid :: G

    function MultiaryOperation{X, Y, Z}(op, args, ▶, grid) where {X, Y, Z}
        return new{X, Y, Z, length(args), typeof(op), typeof(args), typeof(▶), typeof(grid)}(op, args, ▶, grid)
    end
end

@inline Base.getindex(Π::MultiaryOperation{X, Y, Z, N}, i, j, k)  where {X, Y, Z, N} =
    Π.op(ntuple(γ -> Π.▶[γ](i, j, k, Π.grid, Π.args[γ]), Val(N))...)

#####
##### MultiaryOperation construction
#####

function _multiary_operation(L, op, args, Largs, grid) where {X, Y, Z}
    ▶ = Tuple(interpolation_operator(La, L) for La in Largs)
    return MultiaryOperation{L[1], L[2], L[3]}(op, Tuple(gpufriendly(a) for a in args), ▶, grid)
end

"""Return an expression that defines an abstract `MultiaryOperator` named `op` for `AbstractField`."""
function define_multiary_operator(op)
    return quote
        function $op(Lop::Tuple,
                     a::Union{Function, Oceananigans.Fields.AbstractField},
                     b::Union{Function, Oceananigans.Fields.AbstractField},
                     c::Union{Function, Oceananigans.Fields.AbstractField},
                     d::Union{Function, Oceananigans.Fields.AbstractField}...)

            args = tuple(a, b, c, d...)
            grid = Oceananigans.AbstractOperations.validate_grid(args...)

            # Convert any functions to FunctionFields
            args = Tuple(Oceananigans.Fields.fieldify(Lop, a, grid) for a in args)
            Largs = Tuple(Oceananigans.Fields.location(a) for a in args)

            return Oceananigans.AbstractOperations._multiary_operation(Lop, $op, args, Largs, grid)
        end

        $op(a::Union{Function, Oceananigans.Fields.AbstractField},
            b::Union{Function, Oceananigans.Fields.AbstractField},
            c::Union{Function, Oceananigans.Fields.AbstractField},
            d::Union{Function, Oceananigans.Fields.AbstractField}...) = $op(Oceananigans.Fields.location(a), a, b, c, d...)
    end
end

"""
    @multiary op1 op2 op3...

Turn each multiary operator in the list `(op1, op2, op3...)`
into a multiary operator on `Oceananigans.Fields` for use in `AbstractOperations`.

Note that a multiary operator:
    * is a function with two or more arguments: for example, `+(x, y, z)` is a multiary function;
    * must be imported to be extended if part of `Base`: use `import Base: op; @multiary op`;
    * can only be called on `Oceananigans.Field`s if the "location" is noted explicitly; see example.

Example
=======

```jldoctest
julia> harmonic_plus(a, b, c) = 1/3 * (1/a + 1/b + 1/c)
harmonic_plus(generic function with 1 method)

julia> @multiary harmonic_plus
3-element Array{Any,1}:
 :+
 :*
 :harmonic_plus

julia> c, d, e = Tuple(Field(Cell, Cell, Cell, CPU(), RegularCartesianGrid((1, 1, 16), (1, 1, 1))) for i = 1:3);

julia> harmonic_plus(c, d, e) # this calls the original function, which in turn returns a (correct) operation tree
BinaryOperation at (Cell, Cell, Cell)
├── grid: RegularCartesianGrid{Float64,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}}
│   ├── size: (1, 1, 16)
│   └── domain: x ∈ [0.0, 1.0], y ∈ [0.0, 1.0], z ∈ [0.0, -1.0]
└── tree:

* at (Cell, Cell, Cell) via Oceananigans.AbstractOperations.identity
├── 0.3333333333333333
└── + at (Cell, Cell, Cell) via Oceananigans.AbstractOperations.identity
    ├── + at (Cell, Cell, Cell) via Oceananigans.AbstractOperations.identity
    │   ├── / at (Cell, Cell, Cell) via Oceananigans.AbstractOperations.identity
    │   │   ├── 1
    │   │   └── OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}
    │   └── / at (Cell, Cell, Cell) via Oceananigans.AbstractOperations.identity
        │   ├── 1
        │   └── OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}
    └── / at (Cell, Cell, Cell) via Oceananigans.AbstractOperations.identity
        ├── 1
        └── OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}

julia> @at (Cell, Cell, Cell) harmonic_plus(c, d, e) # this returns a `MultiaryOperation` as expected
MultiaryOperation at (Cell, Cell, Cell)
├── grid: RegularCartesianGrid{Float64,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}}
│   ├── size: (1, 1, 16)
│   └── domain: x ∈ [0.0, 1.0], y ∈ [0.0, 1.0], z ∈ [0.0, -1.0]
└── tree:

harmonic_plus at (Cell, Cell, Cell)
├── OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}
├── OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}
└── OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}
"""
macro multiary(ops...)
    expr = Expr(:block)

    for op in ops
        defexpr = define_multiary_operator(op)
        push!(expr.args, :($(esc(defexpr))))

        add_to_operator_lists = quote
            push!(Oceananigans.AbstractOperations.operators, Symbol($op))
            push!(Oceananigans.AbstractOperations.multiary_operators, Symbol($op))
        end

        push!(expr.args, :($(esc(add_to_operator_lists))))
    end

    return expr
end

#####
##### Architecture inference for MultiaryOperation
#####

architecture(Π::MultiaryOperation) = architecture(Π.args...)

function architecture(a, b, c, d...)

    archs = []

    push!(archs, architecture(a, b))
    push!(archs, architecture(a, c))
    append!(archs, [architecture(a, di) for di in d])

    for arch in archs
        if !(arch === nothing)
            return arch
        end
    end

    return nothing
end

#####
##### Nested computations
#####

function compute!(Π::MultiaryOperation)
    c = Tuple(compute!(a) for a in Π.args)
    return nothing
end

#####
##### GPU capabilities
#####

"Adapt `MultiaryOperation` to work on the GPU via CUDAnative and CUDAdrv."
Adapt.adapt_structure(to, multiary::MultiaryOperation{X, Y, Z}) where {X, Y, Z} =
    MultiaryOperation{X, Y, Z}(Adapt.adapt(to, multiary.op), Adapt.adapt(to, multiary.args),
                               Adapt.adapt(to, multiary.▶),  multiary.grid)
