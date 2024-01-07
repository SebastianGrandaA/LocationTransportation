struct Cut
    type::CutType
    expression::AffExpr
    objective_value::Real
end

mutable struct MasterProblem <: ProblemType
    model::Model
    opened_locations::Vector{Int64}
    installed_capacities::Vector{Float64}
    cuts::Vector{Vector{Cut}}
    metrics::Metrics
    history::Vector{Metrics}
end

"""
First stage decisions:
    is_opened
    installed_capacity

Second stage decisions:
    distribution_amount
"""
function MasterProblem(instance::Instance, solver::SOLVER)
    master = Model(solver)

    locations = 1:nb_locations(instance)

    @variable(master, is_opened[locations], Bin) # facility location (y_i)
    @variable(master, installed_capacity[locations] >= 0) # warehouse capacity (z_i)
    @variable(master, θ[locations] >= 0) # second-stage objective value

    # Minimize total cost (fixed cost + capacity cost + transportation cost)
    @objective(
        master,
        Min,
        sum(
            fixed_cost(instance, i) * is_opened[i]
            + capacity_cost(instance, i) * installed_capacity[i]
            + θ[i]
            for i in locations
        )
    )

    # Install capacity only if location is opened constraint
    @constraint(
        master,
        install_opened_locations[i in locations],
        installed_capacity[i] <= maximum_capacity(instance, i) * is_opened[i]
    )

    return MasterProblem(master, [], [], Cut[], Metrics(), Vector{Metrics}())
end

function solve!(master::MasterProblem)::Nothing
    execution_time = @elapsed solve!(master.model)
    termination_status(master.model) == MOI.INFEASIBLE_OR_UNBOUNDED && error("Master is infeasible or unbounded")

    master.opened_locations = value.(master.model[:is_opened]) .> 0.5
    master.installed_capacities = value.(master.model[:installed_capacity])

    master.metrics.execution_time = execution_time
    master.metrics.objective_value = objective_value(master.model)
    master.metrics.expected_recourse = 0 # reset expected recourse

    push!(master.history, deepcopy(master.metrics))

    master.cuts = [] # reset cuts

    @info "MasterProblem solved and updated | Metrics $(str(master.metrics))"

    return nothing
end

function build_cut(master::MasterProblem, objective_value::Real, duals, instance::Instance)::AffExpr
    """
    Builds the cuts for a given location
    TODO: y si hacemos: dual for each constraint ; for i in sites : add dual[i] * model var
    """
    expression = AffExpr(objective_value)

    for i in 1:nb_locations(instance)
        expression += duals[i] * master.model[:installed_capacity][i]
    end

    return expression
end

function add_cut!(::Optimality, master::MasterProblem, expression::AffExpr, location_idx::Int64)::Nothing
    cut = @constraint(master.model, expression <= master.model[:θ][location_idx])

    @info "Location $(location_idx) | Optimality cut added: $cut"

    return nothing
end

function add_cut!(::Feasibility, master::MasterProblem, expression::AffExpr, location_idx::Int64)::Nothing
    cut = @constraint(master.model, expression <= 0)

    @info "Location $(location_idx) | Feasibility cut added: $cut"

    return nothing
end
