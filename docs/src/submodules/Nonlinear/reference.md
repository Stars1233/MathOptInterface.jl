```@meta
CurrentModule = MathOptInterface
DocTestSetup = quote
    import MathOptInterface as MOI
end
DocTestFilters = [r"MathOptInterface|MOI"]
```

# [Nonlinear Modeling](@id NonlinearAPI)

More information can be found in the [Nonlinear](@ref nonlinear_developers)
section of the manual.

```@docs
Nonlinear.Model
```

## [Expressions](@id nonlinear_api_expressions)

```@docs
Nonlinear.ExpressionIndex
Nonlinear.add_expression
```

## [Parameters](@id nonlinear_api_parameters)

```@docs
Nonlinear.ParameterIndex
Nonlinear.add_parameter
```

## [Objectives](@id nonlinear_api_objectives)

```@docs
Nonlinear.set_objective
```

## [Constraints](@id nonlinear_api_constraints)

```@docs
Nonlinear.ConstraintIndex
Nonlinear.add_constraint
Nonlinear.delete
```

## [User-defined operators](@id nonlinear_api_operators)

```@docs
Nonlinear.OperatorRegistry
Nonlinear.DEFAULT_UNIVARIATE_OPERATORS
Nonlinear.DEFAULT_MULTIVARIATE_OPERATORS
Nonlinear.register_operator
Nonlinear.register_operator_if_needed
Nonlinear.assert_registered
Nonlinear.check_return_type
Nonlinear.eval_univariate_function
Nonlinear.eval_univariate_gradient
Nonlinear.eval_univariate_function_and_gradient
Nonlinear.eval_univariate_hessian
Nonlinear.eval_multivariate_function
Nonlinear.eval_multivariate_gradient
Nonlinear.eval_multivariate_hessian
Nonlinear.eval_logic_function
Nonlinear.eval_comparison_function
```

## Automatic-differentiation backends

```@docs
Nonlinear.Evaluator
Nonlinear.AbstractAutomaticDifferentiation
Nonlinear.ExprGraphOnly
Nonlinear.SparseReverseMode
Nonlinear.SymbolicMode
```

## Data-structure

```@docs
Nonlinear.Node
Nonlinear.NodeType
Nonlinear.Expression
Nonlinear.Constraint
Nonlinear.adjacency_matrix
Nonlinear.parse_expression
Nonlinear.convert_to_expr
Nonlinear.ordinal_index
```

## SymbolicAD

```@docs
Nonlinear.SymbolicAD.simplify
Nonlinear.SymbolicAD.simplify!
Nonlinear.SymbolicAD.variables
Nonlinear.SymbolicAD.derivative
Nonlinear.SymbolicAD.gradient_and_hessian
```
