# Copyright (c) 2017: Miles Lubin and contributors
# Copyright (c) 2017: Google Inc.
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestConstraintCountBelongs

using Test

import MathOptInterface as MOI

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_runtests_VectorOfVariables()
    MOI.Bridges.runtests(
        MOI.Bridges.Constraint.CountBelongsToMILPBridge,
        """
        variables: a, n, x, y
        [n, x, y] in CountBelongs(3, Set([2, 4]))
        x in Interval(1.0, 2.0)
        y >= 2.0
        y <= 3.0
        a in ZeroOne()
        """,
        """
        variables: a, n, x, y, z_x1, z_x2, z_y2, z_y3
        1.0 * x + -1.0 * z_x1 + -2.0 * z_x2 == 0.0
        1.0 * y + -2.0 * z_y2 + -3.0 * z_y3 == 0.0
        z_x1 + z_x2 == 1.0
        z_y2 + z_y3 == 1.0
        -1.0 * n + z_x2 + z_y2 == 0.0
        x in Interval(1.0, 2.0)
        y >= 2.0
        y <= 3.0
        z_x1 in ZeroOne()
        z_x2 in ZeroOne()
        z_y2 in ZeroOne()
        z_y3 in ZeroOne()
        a in ZeroOne()
        """,
    )
    return
end

function test_runtests_VectorAffineFunction()
    MOI.Bridges.runtests(
        MOI.Bridges.Constraint.CountBelongsToMILPBridge,
        """
        variables: x, y
        [2.0, 2.0 * x + -1.0, y] in CountBelongs(3, Set([2, 4]))
        x in Interval(1.0, 2.0)
        y >= 2.0
        y <= 3.0
        """,
        """
        variables: x, y, z_x1, z_x2, z_x3, z_y2, z_y3
        2.0 * x + -1.0 * z_x1 + -2.0 * z_x2 + -3.0 * z_x3 == 1.0
        1.0 * y + -2.0 * z_y2 + -3.0 * z_y3 == 0.0
        z_x2 + z_y2 == 2.0
        z_x1 + z_x2 + z_x3 == 1.0
        z_y2 + z_y3 == 1.0
        x in Interval(1.0, 2.0)
        y >= 2.0
        y <= 3.0
        z_x1 in ZeroOne()
        z_x2 in ZeroOne()
        z_x3 in ZeroOne()
        z_y2 in ZeroOne()
        z_y3 in ZeroOne()
        """,
    )
    return
end

function test_resolve_with_modified()
    inner = MOI.Utilities.Model{Int}()
    model = MOI.Bridges.Constraint.CountBelongsToMILP{Int}(inner)
    x = MOI.add_variables(model, 3)
    c = MOI.add_constraint.(model, x, MOI.Interval(1, 2))
    f = MOI.VectorOfVariables(x)
    MOI.add_constraint(model, f, MOI.CountBelongs(3, Set([2, 4])))
    @test MOI.get(inner, MOI.NumberOfVariables()) == 3
    MOI.Bridges.final_touch(model)
    @test MOI.get(inner, MOI.NumberOfVariables()) == 7
    MOI.set(model, MOI.ConstraintSet(), c[2], MOI.Interval(1, 3))
    MOI.Bridges.final_touch(model)
    @test MOI.get(inner, MOI.NumberOfVariables()) == 8
    return
end

function test_runtests_error_variable()
    inner = MOI.Utilities.Model{Int}()
    model = MOI.Bridges.Constraint.CountBelongsToMILP{Int}(inner)
    x = MOI.add_variables(model, 3)
    f = MOI.VectorOfVariables(x)
    c = MOI.add_constraint(model, f, MOI.CountBelongs(3, Set([2, 4])))
    BT = typeof(model.map[c])
    @test_throws(
        MOI.Bridges.BridgeRequiresFiniteDomainError{BT,MOI.VariableIndex},
        MOI.Bridges.final_touch(model),
    )
    return
end

function test_runtests_error_affine()
    inner = MOI.Utilities.Model{Int}()
    model = MOI.Bridges.Constraint.CountBelongsToMILP{Int}(inner)
    x = MOI.add_variables(model, 2)
    f = MOI.Utilities.operate(vcat, Int, 2, 1 * x[1], x[2])
    c = MOI.add_constraint(model, f, MOI.CountBelongs(3, Set([2, 4])))
    BT = typeof(model.map[c])
    F = MOI.ScalarAffineFunction{Int}
    @test_throws(
        MOI.Bridges.BridgeRequiresFiniteDomainError{BT,F},
        MOI.Bridges.final_touch(model),
    )
    return
end

end  # module

TestConstraintCountBelongs.runtests()
