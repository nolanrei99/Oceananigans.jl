using Oceananigans.Fields: AbstractField
using Oceananigans.BoundaryConditions: bctype, CoordinateBoundaryConditions, FieldBoundaryConditions
using Oceananigans.TimeSteppers: QuasiAdamsBashforth2TimeStepper, RungeKutta3TimeStepper

#####
##### Output writer utilities
#####

convert_to_arch(::CPU, a) = a
convert_to_arch(::GPU, a) = CuArray(a)

ext(fw::AbstractOutputWriter) = throw("Extension for $(typeof(fw)) is not implemented.")

# When saving stuff to disk like a JLD2 file, `saveproperty!` is used, which
# converts Julia objects to language-agnostic objects.
saveproperty!(file, location, p::Union{Number,Array}) = file[location] = p
saveproperty!(file, location, p::AbstractRange) = file[location] = collect(p)
saveproperty!(file, location, p::AbstractArray) = file[location] = Array(parent(p))
saveproperty!(file, location, p::Function) = @warn "Cannot save Function property into $location"

saveproperty!(file, location, p::Tuple) =
    [saveproperty!(file, location * "/$i", p[i]) for i in 1:length(p)]

saveproperty!(file, location, p) =
    [saveproperty!(file, location * "/$subp", getproperty(p, subp)) for subp in propertynames(p)]

# Special saveproperty! so boundary conditions are easily readable outside julia.
function saveproperty!(file, location, cbcs::CoordinateBoundaryConditions)
    for endpoint in propertynames(cbcs)
        endpoint_bc = getproperty(cbcs, endpoint)
        if endpoint_bc.condition isa Function
            @warn "$field.$coord.$endpoint boundary is of type Function and cannot be saved to disk!"
            file[location * "/$endpoint/type"] = string(bctype(endpoint_bc))
            file[location * "/$endpoint/condition"] = missing
        else
            file[location * "/$endpoint/type"] = string(bctype(endpoint_bc))
            file[location * "/$endpoint/condition"] = endpoint_bc.condition
        end
    end
end

saveproperties!(file, structure, ps) = [saveproperty!(file, "$p", getproperty(structure, p)) for p in ps]

# When checkpointing, `serializeproperty!` is used, which serializes objects
# unless they need to be converted (basically CuArrays only).
serializeproperty!(file, location, p) = (file[location] = p)
serializeproperty!(file, location, p::AbstractArray) = saveproperty!(file, location, p)
serializeproperty!(file, location, p::Function) = @warn "Cannot serialize Function property into $location"

function serializeproperty!(file, location, p::FieldBoundaryConditions)
    if has_reference(Function, p)
        @warn "Cannot serialize $location as it contains functions. Will replace with missing. " *
              "Function boundary conditions must be restored manually."
        file[location] = missing
    else
        file[location] = p
    end
end

function serializeproperty!(file, location, p::Field{LX, LY, LZ}) where {LX, LY, LZ}
    serializeproperty!(file, location * "/location", (LX(), LY(), LZ()))
    serializeproperty!(file, location * "/data", p.data.parent)
    serializeproperty!(file, location * "/boundary_conditions", p.boundary_conditions)
end

# Special serializeproperty! for AB2 time stepper struct used by the checkpointer so
# it only saves the fields and not the tendency BCs or χ value (as they can be
# constructed by the `Model` constructor).
function serializeproperty!(file, location, 
                            ts::Union{QuasiAdamsBashforth2TimeStepper, RungeKutta3TimeStepper})
    serializeproperty!(file, location * "/Gⁿ", ts.Gⁿ)
    serializeproperty!(file, location * "/G⁻", ts.G⁻)
end

serializeproperty!(file, location, p::NamedTuple) =
    [serializeproperty!(file, location * "/$subp", getproperty(p, subp)) for subp in keys(p)]

serializeproperties!(file, structure, ps) =
    [serializeproperty!(file, "$p", getproperty(structure, p)) for p in ps]

# Don't check arrays because we don't need that noise.
has_reference(T, ::AbstractArray{<:Number}) = false

# This is going to be true.
has_reference(::Type{T}, ::NTuple{N, <:T}) where {N, T} = true

# Short circuit on fields.
has_reference(T::Type{Function}, f::Field) =
    has_reference(T, f.data) || has_reference(T, f.boundary_conditions)

"""
    has_reference(has_type, obj)

Check (or attempt to check) if `obj` contains, somewhere among its
subfields and subfields of fields, a reference to an object of type
`has_type`. This function doesn't always work.
"""
function has_reference(has_type, obj)
    if typeof(obj) <: has_type
        return true
    elseif applicable(iterate, obj) && length(obj) > 1
        return any([has_reference(has_type, elem) for elem in obj])
    elseif applicable(propertynames, obj) && length(propertynames(obj)) > 0
        return any([has_reference(has_type, getproperty(obj, p)) for p in propertynames(obj)])
    else
        return typeof(obj) <: has_type
    end
end
