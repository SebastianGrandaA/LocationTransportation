"""
    solve(::AffineDecision)

The affine decision rule states that the second-stage decisions, which are the transportation quantities, are affine functions of the uncertain demand.
The solutions of the affine decision rule are expected to be less conservative than the classical Robust Optimization approach because they yield more flexible decisions that can be adjusted according to the realized proportion of data at a given stage.
"""
function solve(method::AffineDecision, instance::Instance, solver::SOLVER)::Solution
    model = Model(solver)

    robust_demand = UncertaintySet(instance, solver).demand

    locations = 1:nb_locations(instance)
    customers = 1:nb_customers(instance)

    @variable(model, is_opened[locations], Bin) # facility location
    @variable(model, installed_capacity[locations] >= 0) # warehouse capacity
    @variable(model, nominal_distribution_amount[locations, customers] >= 0) # base transportation quantity
    @variable(model, distribution_coefficients[locations, customers, customers] >= 0) # distribution coefficients
    @variable(model, distribution_amount[locations, customers] >= 0) # auxiliary variable

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

    # Affine decision rule constraint
    @constraint(
        model,
        affine_decision_rule[i in locations, j in customers],
        distribution_amount[i, j]
        >= nominal_distribution_amount[i, j] + sum(distribution_coefficients[i, j, k] * robust_demand[k] for k in customers)
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

    # Demand satisfaction constraint (affine)
    @constraint(
        model,
        demand_satisfaction[j in customers],
        sum(distribution_amount[i, j] for i in locations)
        >= robust_demand[j]
    )

    execution_time = @elapsed solve!(model)

    return Solution(method, instance, model, execution_time)
end
