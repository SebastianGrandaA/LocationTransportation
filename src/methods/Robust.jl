"""
Robust Optimization (RO) is a methodology for optimization under uncertainty.
Contrary to stochastic optimization, robust optimization does not rely on probability distributions.
Instead, RO considers an uncertainty set for the unknown parameters, against which the taken decision should be immune.
In that sense, constraints have to be respected in every possible realization of the parameters and the objective function evaluated in the worst-case scenario.

In other words, solutions must be feasible for all possible realizations of the uncertain parameters. This leads to over-conservative solutions.
To trackle this issue, consider the Adjustable Robust Optimization (ARO) approach, which restricts the second-stage variables to affine functions of the uncertainty.

Other alternative is to consider an approximate method. In the affine decision rule approach, the second-stage decisions are expressed as affine functions of the uncertainty.

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

