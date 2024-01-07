"""
    SubProblem

Given a first-stage solution, generates feasibility and optimality cuts for the master problem.
"""
struct SubProblem <: ProblemType
    customer_idx::Int64
    cut::Cut
    model::Model
    metrics::Metrics
end

is_feasible(::Feasibility, objective_value::Real)::Bool = isapprox(objective_value, 0)

"""
    SubProblem(::Optimality)

Sencond-stage problem.
"""
function SubProblem(
    cut_type::Optimality,
    solver::SOLVER,
    instance::Instance,
    master::MasterProblem,
    customer_idx::Int64,
    robust_demand::Vector{Float64}
)
    subproblem = Model(solver)

    locations = 1:nb_locations(instance)

    @variable(subproblem, distribution_amount[locations] >= 0) # transportation quantity

    # Minimize total transportation cost
    @objective(
        subproblem,
        Min,
        sum(
            transport_cost(instance, i, customer_idx) * distribution_amount[i]
            for i in locations
        )
    )

    # Transport products from opened locations constraint
    @constraint(
        subproblem,
        transport_opened_locations[i in locations],
        distribution_amount[i] <= master.installed_capacities[i]
    )

    # Demand satisfaction constraint (robust)
    @constraint(
        subproblem,
        demand_satisfaction,
        sum(distribution_amount[i] for i in locations) >= robust_demand[customer_idx]
    )

    solve!(subproblem)
    is_optimal = termination_status(subproblem) == MOI.OPTIMAL
    !(is_optimal) && return nothing

    metrics = Metrics(objective_value = objective_value(subproblem))

    duals = dual.(subproblem[:transport_opened_locations])
    cut = Cut(
        cut_type,
        build_cut(master, metrics.objective_value, duals, instance),
        metrics.objective_value,
    )

    return SubProblem(customer_idx, cut, subproblem, metrics)
end

"""
    SubProblem(::Feasibility)
"""
function SubProblem(
    cut_type::Feasibility,
    solver::SOLVER,
    instance::Instance,
    master::MasterProblem,
    customer_idx::Int64,
    robust_demand::Vector{Float64}
)
    auxiliary = Model(solver)

    locations = 1:nb_locations(instance)

    @variable(auxiliary, distribution_amount[locations] >= 0) # transportation quantity
    @variable(auxiliary, capacity_deficit[locations] >= 0)
    @variable(auxiliary, capacity_surplus[locations] >= 0)

    # Minimize sum of artificial variables
    @objective(
        auxiliary,
        Min,
        sum(
            capacity_deficit[i] + capacity_surplus[i]
            for i in locations
        )
    )

    # Transport products from opened locations constraint
    @constraint(
        auxiliary,
        transport_opened_locations[i in locations],
        distribution_amount[i] + capacity_deficit[i] - capacity_surplus[i] <= master.installed_capacities[i]
    )

    # Demand satisfaction constraint (robust)
    @constraint(
        auxiliary,
        demand_satisfaction,
        sum(distribution_amount[i] for i in locations) >= robust_demand[customer_idx]
    )

    solve!(auxiliary)

    metrics = Metrics(objective_value = objective_value(auxiliary))
    is_feasible(cut_type, metrics.objective_value) && return nothing

    duals = dual.(auxiliary[:transport_opened_locations])
    cut = Cut(
        cut_type,
        build_cut(master, metrics.objective_value, duals, instance),
        NaN,
    )

    return SubProblem(customer_idx, cut, auxiliary, metrics)
end
