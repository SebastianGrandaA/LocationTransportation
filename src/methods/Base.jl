"""
Location-transportation problem with single product.
The decisions are to store a product at a warehouse location and to transport it to the customer location.
Therefore, a first-stage decision is to determine wether to build a warehouse in a potential location and to determine the capacity of the warehouse.

TODO this is P1. Probar implementar P2 (y comparar )
"""
function solve(method::Base, instance::Instance, solver::SOLVER)::Solution
    model = Model(solver)

    locations = 1:nb_locations(instance)
    customers = 1:nb_customers(instance)

    @variable(model, is_opened[locations], Bin) # facility location (y_i)
    @variable(model, installed_capacity[locations] >= 0) # warehouse capacity (z_i)
    @variable(model, distributed_ammount[locations, customers] >= 0) # transportation quantity (x_ij)

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

    # Demand satisfaction constraint
    @constraint(
        model,
        demand_satisfaction[j in customers],
        sum(distributed_ammount[i, j] for i in locations) >= demand(instance, j)
    )

    execution_time = @elapsed solve!(model)

    return Solution(method, instance, model, execution_time)
end

