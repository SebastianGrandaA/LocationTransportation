module LocationTransportation

using JuMP
using Gurobi

abstract type Method end
struct Base <: Method end
struct Robust <: Method end
struct ConstraintGeneration <: Method end
struct AffineDecision <: Method end

const SOLVER = MOI.OptimizerWithAttributes

include("services/instances.jl")
include("services/solutions.jl")
include("services/helpers.jl")

include("methods/Base.jl")
include("methods/Robust.jl")
include("methods/ConstraintGeneration.jl")
include("methods/AffineDecision.jl")


"""
Entry-point
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
    # show!(instance, solution)

    # Export solution
    # output_path = joinpath(pwd(), "outputs")
    # export_solution(model_name, joinpath(output_path, "$(filename)_$(model_name)"), instance, solution)

    # run_benchmark = get(kwargs, :benchmark, true)
    # usage = get(kwargs, :usage, nothing)
    # run_benchmark && add!(joinpath(output_path, "benchmark.csv"), instance, solution, usage)

    return solution
end

export execute

end # module LocationTransportation
