"""
Introduce 2 variables that replace ...
    Replace the `distribution_amount` variable with two variables: `base_distributed_amount` and `distribution_coefficients`.

* W_{ijk} : how the distribution from warehouse i to customer j is affected by the demand of customer k.
    The `distribution_coefficients` variable represents the deviation from the nominal value of the transportation quantity, which are the coefficients of the affine decision rule.
    
    @variable(model, distribution_coefficients[locations, customers, customers])

* \bar{x}_{ij} : nominal value of the transportation quantity from warehouse i to customer j.
    The `base_distributed_amount` variable represents the nominal value of the transportation quantity.
    
    @variable(model, base_distributed_amount[locations, customers] >= 0)

Also, define an additional constraint to capture the affine relationship between the second-stage variables and the uncertain parameters.
    The `demand_satisfaction` constraint is reformulated to include the uncertainty set.


# TODO assert solution is less conservative than the classical RO approach
   
The objective function remains the same
    
TODO corroborar con notability -- ejercicios clase
TODO ver notes en TODO.jl

"""
function solve(method::AffineDecision, instance::Instance, solver::SOLVER)::Solution
    model = Model(solver)

    robust_demand = UncertaintySet(instance, solver).demand

    locations = 1:nb_locations(instance)
    customers = 1:nb_customers(instance)

    # we introduce two variables (and keep distribution_amount)
    @variable(model, is_opened[locations], Bin) # facility location
    @variable(model, installed_capacity[locations] >= 0) # warehouse capacity
    @variable(model, base_distributed_amount[locations, customers] >= 0) # base transportation quantity
    # TODO es lo mismo [customers, customers] que [customers]??? Si lo es solo usar [customers]?
    @variable(model, distribution_coefficients[locations, customers, customers] >= 0) # distribution coefficients
    # @variable(model, distribution_coefficients[locations, customers] >= 0) # distribution coefficients
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
        >= base_distributed_amount[i, j] + sum(distribution_coefficients[i, j, k] * robust_demand[k] for k in customers)
        # >= base_distributed_amount[i, j] + distribution_coefficients[i, j] * robust_demand[j]
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
