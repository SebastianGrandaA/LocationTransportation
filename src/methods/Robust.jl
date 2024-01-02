"""
Robust counterpart
"""
function solve(method::Robust, instance::Instance, solver::SOLVER)::Solution
    model = Model(solver)

    locations = 1:nb_locations(instance)
    customers = 1:nb_customers(instance)
    Γ = get(instance.params, :Γ, [1.0 for _ in customers]) # uncertainty budget

    @variable(model, is_opened[locations], Bin) # facility location (y_i)
    @variable(model, installed_capacity[locations] >= 0) # warehouse capacity (z_i)
    @variable(model, distributed_ammount[locations, customers] >= 0) # transportation quantity (x_ij)
    @variable(model, M[customers] >= 0) # maximum demand (M_j)
    @variable(model, 0 <= δ[customers] <= 1) # level of uncertainty (δ_j) - proportion of the deviation

    # Minimize total cost (fixed cost + capacity cost + transportation cost)
    @objective(
        model,
        Min,
        sum(
            fixed_cost(instance, i) * is_opened[i]
            + capacity_cost(instance, i) * installed_capacity[i]
            + sum(transport_cost(instance, i, j) * distributed_ammount[i, j] for j in customers)
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
        sum(distributed_ammount[i, j] for j in customers) <= installed_capacity[i]
    )

    # TODO creo que en base a la teoria, toca dualisar el D y adjuntar a patir de ello las restricciones

    # Demand satisfaction constraint (worst case)
    @constraint(
        model,
        demand_satisfaction[j in customers],
        sum(distributed_ammount[i, j] for i in locations) >= M[j]
    )

    # Maximum demand definition
    @constraint(
        model,
        maximum_demand[j in customers],
        M[j] >= demand_base(instance, j) + demand_deviation(instance, j) * δ[j]
    )

    # Uncertainty set constraints
    @constraint(
        model,
        uncertainty_set[j in customers],
        sum(δ[j] for j in customers) <= Γ[1]
    )

    @constraint(
        model,
        δ[1] + δ[2] <= Γ[2]
    )

    execution_time = @elapsed solve!(model)

    @info "Robust | Solution values" value.(M) value.(δ)

    return Solution(method, instance, model, execution_time)
end
