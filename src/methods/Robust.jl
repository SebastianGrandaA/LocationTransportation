"""
    solve(::Robust)

Solve the LocationTransportation problem using the robust model using the given instance and solver.
The robust model is obtained by solving the uncertainty set problem.
"""
function solve(method::Robust, instance::Instance, solver::SOLVER)::Solution
    model = Model(solver)

    robust_demand = UncertaintySet(instance, solver).demand

    locations = 1:nb_locations(instance)
    customers = 1:nb_customers(instance)

    @variable(model, is_opened[locations], Bin) # location
    @variable(model, installed_capacity[locations] >= 0) # capacity
    @variable(model, distribution_amount[locations, customers] >= 0) # transportation quantity

    # Minimize total cost (fixed cost + capacity cost + transportation cost)
    @objective(
        model,
        Min,
        sum(
            fixed_cost(instance, i) * is_opened[i]
            + capacity_cost(instance, i) * installed_capacity[i]
            + sum(transport_cost(instance, i, j) * distribution_amount[i, j] for j in customers)
            for i in locations
        )
    )

    # Install capacity only if location is opened constraint
    @constraint(
        model,
        install_opened_locations[i in locations],
        installed_capacity[i] <= maximum_capacity(instance, i) * is_opened[i]
    )

    # Transport products from opened locations constraint
    @constraint(
        model,
        transport_opened_locations[i in locations],
        sum(distribution_amount[i, j] for j in customers) <= installed_capacity[i]
    )

    # Demand satisfaction constraint (robust)
    @constraint(
        model,
        demand_satisfaction[j in customers],
        sum(model[:distribution_amount][i, j] for i in locations) >= robust_demand[j]
    )

    execution_time = @elapsed solve!(model)

    return Solution(method, instance, model, execution_time)
end
