# Copyright (c) 2017: Miles Lubin and contributors
# Copyright (c) 2017: Google Inc.
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

abstract type _AbstractSlackBridge{T,VF,ZS,F,S} <: AbstractBridge end

function MOI.Bridges.added_constrained_variable_types(
    ::Type{<:_AbstractSlackBridge{T,VF,ZS,F,S}},
) where {T,VF,ZS,F,S}
    return Tuple{Type}[(S,)]
end

function MOI.Bridges.added_constraint_types(
    ::Type{<:_AbstractSlackBridge{T,VF,ZS,F}},
) where {T,VF,ZS,F}
    return Tuple{Type,Type}[(F, ZS)]
end

function MOI.get(
    ::_AbstractSlackBridge{T,VF,ZS,F},
    ::MOI.NumberOfConstraints{F,ZS},
)::Int64 where {T,VF,ZS,F}
    return 1
end

function MOI.get(
    bridge::_AbstractSlackBridge{T,VF,ZS,F},
    ::MOI.ListOfConstraintIndices{F,ZS},
) where {T,VF,ZS,F}
    return [bridge.equality]
end

function MOI.get(
    ::_AbstractSlackBridge{T,VF,ZS,F,S},
    ::MOI.NumberOfConstraints{VF,S},
)::Int64 where {T,VF,ZS,F,S}
    return 1
end

function MOI.get(
    bridge::_AbstractSlackBridge{T,VF,ZS,F,S},
    ::MOI.ListOfConstraintIndices{VF,S},
) where {T,VF,ZS,F,S}
    return [bridge.slack_in_set]
end

function MOI.get(
    ::_AbstractSlackBridge{T,VF,S,F,S},
    ::MOI.NumberOfConstraints{VF,S},
)::Int64 where {T,VF,F,S}
    # This method is needed to resolve a possible ambiguity reported by
    # Test.detect_ambiguities. It can't happen in practice because it would mean
    # that the original set was the same as the slacked set.
    return error(
        "Internal error: this method should never be called because it " *
        "represents an invalid state. Please open an issue to report.",
    )
end

function MOI.get(
    bridge::_AbstractSlackBridge{T,VF,S,F,S},
    ::MOI.ListOfConstraintIndices{VF,S},
) where {T,VF,S,F}
    # This method is needed to resolve a possible ambiguity reported by
    # Test.detect_ambiguities. It can't happen in practice because it would mean
    # that the original set was the same as the slacked set.
    return error(
        "Internal error: this method should never be called because it " *
        "represents an invalid state. Please open an issue to report.",
    )
end

function MOI.delete(model::MOI.ModelLike, bridge::_AbstractSlackBridge)
    MOI.delete(model, bridge.equality)
    MOI.delete(model, bridge.slack)
    return
end

function MOI.supports(
    model::MOI.ModelLike,
    attr::Union{MOI.ConstraintPrimalStart,MOI.ConstraintDualStart},
    ::Type{<:_AbstractSlackBridge{T,VF,ZS,F,S}},
) where {T,VF,ZS,F,S}
    ret = true
    if attr isa MOI.ConstraintPrimalStart
        ret = MOI.supports(model, MOI.VariablePrimalStart(), MOI.VariableIndex)
    end
    # .slack_in_set field is {VF,S}
    # .equality field is {F,ZS}
    return ret &&
           MOI.supports(model, attr, MOI.ConstraintIndex{VF,S}) &&
           MOI.supports(model, attr, MOI.ConstraintIndex{F,ZS})
end

function MOI.get(
    model::MOI.ModelLike,
    attr::Union{MOI.ConstraintPrimal,MOI.ConstraintPrimalStart},
    bridge::_AbstractSlackBridge,
)
    # Due to equality, slack should have the same value as original affine
    # function.
    return MOI.get(model, attr, bridge.slack_in_set)
end

function MOI.set(
    model::MOI.ModelLike,
    attr::MOI.ConstraintPrimalStart,
    bridge::_AbstractSlackBridge,
    value,
)
    if bridge isa ScalarSlackBridge
        MOI.set(model, MOI.VariablePrimalStart(), bridge.slack, value)
    else
        MOI.set.(model, MOI.VariablePrimalStart(), bridge.slack, value)
    end
    MOI.set(model, attr, bridge.slack_in_set, value)
    start = value === nothing ? nothing : zero(value)
    MOI.set(model, attr, bridge.equality, start)
    return
end

function MOI.get(
    model::MOI.ModelLike,
    a::Union{MOI.ConstraintDual,MOI.ConstraintDualStart},
    bridge::_AbstractSlackBridge{T},
) where {T}
    # The dual constraint on slack (since it is free) is
    # `-dual_slack_in_set + dual_equality = 0` so the two duals are
    # equal (modulo a rescaling for things like symmetric matrices) and we can
    # return either one of them.
    #
    # We decide to use the dual of the equality constraints because the
    # `slack_in_set` constraint might be bridged by a variable bridge that does
    # not support `ConstraintDual`. This is the case if the adjoint of the
    # linear map on which the bridge is based is not invertible, for example,
    # `Variable.ZerosBridge` or `SumOfSquares.Bridges.Variable.KernelBridge`.
    dual = MOI.get(model, a, bridge.equality)
    if dual === nothing
        return nothing
    elseif dual isa AbstractVector
        # The equality constraints gives the term <dual, primal> with the
        # standard inner product but <dual, primal>_PSD is like scaling each
        # entry of dual and primal by the entry of SetDotScalingVector. To undo,
        # we need to divide by the square.
        scale = MOI.Utilities.SetDotScalingVector{T}(bridge.set)
        return dual ./ scale .^ 2
    end
    return dual
end

function MOI.set(
    model::MOI.ModelLike,
    attr::MOI.ConstraintDualStart,
    bridge::_AbstractSlackBridge{T},
    value,
) where {T}
    # See comments in MOI.get for why we need to rescale, etc.
    MOI.set(model, attr, bridge.slack_in_set, value)
    if value isa AbstractVector
        scale = MOI.Utilities.SetDotScalingVector{T}(bridge.set)
        MOI.set(model, attr, bridge.equality, value .* scale .^ 2)
    else
        MOI.set(model, attr, bridge.equality, value)
    end
    return
end

function MOI.modify(
    model::MOI.ModelLike,
    bridge::_AbstractSlackBridge,
    change::MOI.AbstractFunctionModification,
)
    MOI.modify(model, bridge.equality, change)
    return
end

function MOI.set(
    model::MOI.ModelLike,
    ::MOI.ConstraintSet,
    bridge::_AbstractSlackBridge{T,VF,ZS,F,S},
    change::S,
) where {T,VF,ZS,F,S}
    MOI.set(model, MOI.ConstraintSet(), bridge.slack_in_set, change)
    return
end

function MOI.get(
    model::MOI.ModelLike,
    attr::MOI.ConstraintFunction,
    bridge::_AbstractSlackBridge,
)
    return MOI.Utilities.remove_variable(
        MOI.get(model, attr, bridge.equality),
        bridge.slack,
    )
end

function MOI.get(
    model::MOI.ModelLike,
    attr::MOI.ConstraintSet,
    bridge::_AbstractSlackBridge,
)
    return MOI.get(model, attr, bridge.slack_in_set)
end

"""
    ScalarSlackBridge{T,F,S} <: Bridges.Constraint.AbstractBridge

`ScalarSlackBridge` implements the following reformulation:

  * ``f(x) \\in S`` into ``f(x) - y == 0`` and ``y \\in S``

## Source node

`ScalarSlackBridge` supports:

  * `G` in `S`, where `G` is not [`MOI.VariableIndex`](@ref) and `S` is not
    [`MOI.EqualTo`](@ref)

## Target nodes

`ScalarSlackBridge` creates:

  * `F` in [`MOI.EqualTo{T}`](@ref)
  * [`MOI.VariableIndex`](@ref) in `S`
"""
struct ScalarSlackBridge{T,F,S} <:
       _AbstractSlackBridge{T,MOI.VariableIndex,MOI.EqualTo{T},F,S}
    slack::MOI.VariableIndex
    set::S
    slack_in_set::MOI.ConstraintIndex{MOI.VariableIndex,S}
    equality::MOI.ConstraintIndex{F,MOI.EqualTo{T}}
end

const ScalarSlack{T,OT<:MOI.ModelLike} =
    SingleBridgeOptimizer{ScalarSlackBridge{T},OT}

function bridge_constraint(
    ::Type{ScalarSlackBridge{T,F,S}},
    model,
    f::MOI.AbstractScalarFunction,
    s::S,
) where {T,F,S}
    MOI.throw_if_scalar_and_constant_not_zero(f, typeof(s))
    slack, slack_in_set = MOI.add_constrained_variable(model, s)
    new_f = MOI.Utilities.operate(-, T, f, slack)
    equality = MOI.add_constraint(model, new_f, MOI.EqualTo(zero(T)))
    return ScalarSlackBridge{T,F,S}(slack, s, slack_in_set, equality)
end

# Start by allowing all scalar constraints:

function MOI.supports_constraint(
    ::Type{ScalarSlackBridge{T}},
    F::Type{<:MOI.AbstractScalarFunction},
    ::Type{<:MOI.AbstractScalarSet},
) where {T}
    return MOI.Utilities.is_coefficient_type(F, T)
end

# Then restrict, being careful with method ambiguities

function MOI.supports_constraint(
    ::Type{ScalarSlackBridge{T}},
    ::Type{<:MOI.VariableIndex},
    ::Type{<:MOI.EqualTo},
) where {T}
    return false
end

function MOI.supports_constraint(
    ::Type{ScalarSlackBridge{T}},
    ::Type{<:MOI.VariableIndex},
    ::Type{<:MOI.AbstractScalarSet},
) where {T}
    return false
end

function MOI.supports_constraint(
    ::Type{ScalarSlackBridge{T}},
    ::Type{<:MOI.AbstractScalarFunction},
    ::Type{<:MOI.EqualTo},
) where {T}
    return false
end

function concrete_bridge_type(
    ::Type{<:ScalarSlackBridge{T}},
    F::Type{<:MOI.AbstractScalarFunction},
    S::Type{<:MOI.AbstractScalarSet},
) where {T}
    F2 = MOI.Utilities.promote_operation(-, T, F, MOI.VariableIndex)
    return ScalarSlackBridge{T,F2,S}
end

MOI.get(b::ScalarSlackBridge, ::MOI.NumberOfVariables)::Int64 = 1

MOI.get(b::ScalarSlackBridge, ::MOI.ListOfVariableIndices) = [b.slack]

function MOI.get(
    model::MOI.ModelLike,
    ::MOI.ConstraintBasisStatus,
    bridge::ScalarSlackBridge{T,F,S},
) where {T,F,S<:MOI.Interval}
    return MOI.get(
        model,
        MOI.VariableBasisStatus(),
        MOI.VariableIndex(bridge.slack_in_set.value),
    )
end

function MOI.get(
    model::MOI.ModelLike,
    ::MOI.ConstraintBasisStatus,
    bridge::ScalarSlackBridge,
)
    status = MOI.get(
        model,
        MOI.VariableBasisStatus(),
        MOI.VariableIndex(bridge.slack_in_set.value),
    )
    if status == MOI.NONBASIC_AT_LOWER || status == MOI.NONBASIC_AT_UPPER
        return MOI.NONBASIC
    end
    return status
end

function MOI.set(
    model::MOI.ModelLike,
    ::MOI.ConstraintFunction,
    bridge::ScalarSlackBridge{T,F,S},
    func::F,
) where {T,F,S}
    new_func = MOI.Utilities.operate(-, T, func, bridge.slack)
    MOI.set(model, MOI.ConstraintFunction(), bridge.equality, new_func)
    return
end

"""
    VectorSlackBridge{T,F,S} <: Bridges.Constraint.AbstractBridge

`VectorSlackBridge` implements the following reformulation:

  * ``f(x) \\in S`` into ``f(x) - y \\in \\{0\\}`` and ``y \\in S``

## Source node

`VectorSlackBridge` supports:

  * `G` in `S`, where `G` is not [`MOI.VectorOfVariables`](@ref) and `S` is not
    [`MOI.Zeros`](@ref)

## Target nodes

`VectorSlackBridge` creates:

  * `F` in [`MOI.Zeros`](@ref)
  * [`MOI.VectorOfVariables`](@ref) in `S`
"""
struct VectorSlackBridge{T,F,S} <:
       _AbstractSlackBridge{T,MOI.VectorOfVariables,MOI.Zeros,F,S}
    slack::Vector{MOI.VariableIndex}
    set::S
    slack_in_set::MOI.ConstraintIndex{MOI.VectorOfVariables,S}
    equality::MOI.ConstraintIndex{F,MOI.Zeros}
end

const VectorSlack{T,OT<:MOI.ModelLike} =
    SingleBridgeOptimizer{VectorSlackBridge{T},OT}

function bridge_constraint(
    ::Type{VectorSlackBridge{T,F,S}},
    model,
    f::MOI.AbstractVectorFunction,
    s::S,
) where {T,F,S}
    d = MOI.dimension(s)
    slack, slack_in_set = MOI.add_constrained_variables(model, s)
    new_f = MOI.Utilities.operate(-, T, f, MOI.VectorOfVariables(slack))
    equality = MOI.add_constraint(model, new_f, MOI.Zeros(d))
    return VectorSlackBridge{T,F,S}(slack, s, slack_in_set, equality)
end

function MOI.supports_constraint(
    ::Type{VectorSlackBridge{T}},
    F::Type{<:MOI.AbstractVectorFunction},
    ::Type{<:MOI.AbstractVectorSet},
) where {T}
    return MOI.Utilities.is_coefficient_type(F, T)
end

function MOI.supports_constraint(
    ::Type{VectorSlackBridge{T}},
    ::Type{<:MOI.VectorOfVariables},
    ::Type{<:MOI.Zeros},
) where {T}
    return false
end

function MOI.supports_constraint(
    ::Type{VectorSlackBridge{T}},
    ::Type{<:MOI.AbstractVectorFunction},
    ::Type{<:MOI.Zeros},
) where {T}
    return false
end

function MOI.supports_constraint(
    ::Type{VectorSlackBridge{T}},
    ::Type{<:MOI.VectorOfVariables},
    ::Type{<:MOI.AbstractVectorSet},
) where {T}
    return false
end

function concrete_bridge_type(
    ::Type{<:VectorSlackBridge{T}},
    F::Type{<:MOI.AbstractVectorFunction},
    S::Type{<:MOI.AbstractVectorSet},
) where {T}
    F2 = MOI.Utilities.promote_operation(-, T, F, MOI.VectorOfVariables)
    return VectorSlackBridge{T,F2,S}
end

MOI.get(b::VectorSlackBridge, ::MOI.NumberOfVariables)::Int64 = length(b.slack)

MOI.get(b::VectorSlackBridge, ::MOI.ListOfVariableIndices) = copy(b.slack)

function MOI.set(
    model::MOI.ModelLike,
    ::MOI.ConstraintFunction,
    bridge::VectorSlackBridge{T,F,S},
    func::F,
) where {T,F,S}
    slack = MOI.VectorAffineFunction{T}(MOI.VectorOfVariables(bridge.slack))
    new_func = MOI.Utilities.operate(-, T, func, slack)
    MOI.set(model, MOI.ConstraintFunction(), bridge.equality, new_func)
    return
end
