# Copyright (c) 2017: Miles Lubin and contributors
# Copyright (c) 2017: Google Inc.
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Nonlinear

import ForwardDiff
import ..MathOptInterface as MOI
import OrderedCollections: OrderedDict
import SparseArrays

using SpecialFunctions

# Override basic math functions to return NaN instead of throwing errors.
# This is what NLP solvers expect, and sometimes the results aren't needed
# anyway, because the code may compute derivatives wrt constants.
import NaNMath:
    sin,
    cos,
    tan,
    asin,
    acos,
    acosh,
    atanh,
    log,
    log2,
    log10,
    lgamma,
    log1p,
    pow,
    sqrt

include("univariate_expressions.jl")
include("operators.jl")
include("types.jl")
include("parse.jl")
include("model.jl")
include("evaluator.jl")

include("ReverseAD/ReverseAD.jl")
include("SymbolicAD/SymbolicAD.jl")

end  # module
