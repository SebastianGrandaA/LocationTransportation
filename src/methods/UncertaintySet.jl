"""
    UncertaintySet

Determine the robust demand quantity for each customer.
"""
struct UncertaintySet
    demand::Vector{Float64} # robust demand per customer
end

function UncertaintySet(instance::Instance, solver::SOLVER)
    model = Model(solver)

    customers = 1:nb_customers(instance)
    Γ = get(instance.params, :Γ, [1.0 for _ in customers]) # uncertainty budget

    @variable(model, nominal_demand[customers] >= 0) # nominal demand
    @variable(model, 0 <= δ[customers] <= 1) # deviation proportion

    # Maximize demand quantity
    @objective(
        model,
        Max,
        sum(nominal_demand)
    )
    
    @constraint(
        model,
        uncertain_demand_definition[j in customers],
        nominal_demand[j] == demand_base(instance, j) + demand_deviation(instance, j) * δ[j]
    )

    @constraint(
        model,
        uncertain_budget_1,
        sum(δ) <= Γ[1]
    )

    @constraint(
        model,
        uncertain_budget_2,
        δ[1] + δ[2] <= Γ[2]
    )

    solve!(model)

    nominal_demand = value.(nominal_demand)
    duals = dual.(model[:uncertain_demand_definition])
    robust_demand = -1 .* duals .* nominal_demand

    return UncertaintySet(robust_demand)
end
