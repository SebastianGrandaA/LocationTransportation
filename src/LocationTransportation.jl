module LocationTransportation

using JuMP
using Gurobi
using Distributed
using DataFrames

abstract type Method end
struct Base <: Method end
struct Robust <: Method end
struct ConstraintGeneration <: Method end
struct AffineDecision <: Method end

abstract type CutType end
struct Feasibility <: CutType end
struct Optimality <: CutType end

abstract type ProblemType end

const SOLVER = MOI.OptimizerWithAttributes
const LOCATION_PREFFIX = "L"
const CUSTOMER_PREFFIX = "C"
const SUBPROBLEM_CONSTRAINTS = 2
const MAXIMUM_ITERATIONS = 5

include("services/instances.jl")
include("services/solutions.jl")
include("services/helpers.jl")

include("methods/Base.jl")
include("methods/UncertaintySet.jl")
include("methods/Robust.jl")
include("methods/Benders/MasterProblem.jl")
include("methods/Benders/SubProblem.jl")
include("methods/Benders/ConstraintGeneration.jl")
include("methods/AffineDecision.jl")

"""
    optimize(model_name::Symbol, instance::Instance, solver::SOLVER)

Dispatches to the corresponding optimization method.
"""
function optimize(model_name::Symbol, instance::Instance, solver::SOLVER)::Union{Solution, Nothing}
    try
        method = eval(model_name)()
        @info "Solving instance with $(model_name)"

        return solve(method, instance, solver)
    catch err
        @error "$(model_name) | Error while solving | Error: $err"
    end

    return nothing
end

"""
    execute(; kwargs...)::Union{Solution, Nothing}

Entry-point for solving the instance with the given model and solver.
"""
function execute(; kwargs...)::Union{Solution, Nothing}
    # Set solver
    verbose = get(kwargs, :verbose, false) == true ? 1 : 0
    solver = optimizer_with_attributes(
        Gurobi.Optimizer,
        "OutputFlag" => verbose,
        "TimeLimit" => get(kwargs, :limit, 1 * 60 * 60),
    )

    # Load instance
    instance = Instance(; kwargs...)
    !(is_feasible(instance)) && error("Instance is not feasible")

    # Optimize
    model_name = kwargs[:model]
    solution = optimize(model_name, instance, solver)
    isnothing(solution) && return nothing

    return solution
end

export execute

end # module LocationTransportation
