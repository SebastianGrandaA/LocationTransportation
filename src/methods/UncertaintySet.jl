struct UncertaintySet
    demand::Vector{Float64} # robust demand per customer
    model::Model # TODO borrar si no e sutilizado..
end

"""
Determine the maximum demand quantity for each customer
Reformulate the demand satisfaction constraint to include the uncertainty set

TODO esto no deberia ser parte del problema?? Para asegurar la peor demanda en cualquier escenario??
"""
function UncertaintySet(instance::Instance, solver::SOLVER)
    model = Model(solver)

    customers = 1:nb_customers(instance)
    Γ = get(instance.params, :Γ, [1.0 for _ in customers]) # uncertainty budget

    @variable(model, base_demand[customers] >= 0) # base_demand -- maximum demand quantity (d_j)
    @variable(model, 0 <= δ[customers] <= 1) # deviation proportion --- level of uncertainty (δ_j) - proportion of the deviation

    # Maximize demand quantity
    @objective(
        model,
        Max,
        sum(base_demand)
    )
    
    @constraint(
        model,
        uncertain_demand_definition[j in customers],
        base_demand[j] == demand_base(instance, j) + demand_deviation(instance, j) * δ[j]
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

    base_demand = value.(base_demand)
    duals = dual.(model[:uncertain_demand_definition])
    robust_demand = -1 .* duals .* base_demand
    @info "Uncertainty set obtained" robust_demand

    return UncertaintySet(robust_demand, model)
end
