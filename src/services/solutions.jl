@kwdef mutable struct Metrics
    objective_value::Real = NaN
    execution_time::Real = NaN
    expected_recourse::Real = 0
end

function str(metrics::Metrics)::String
    values = [
        "$(property): $(getfield(metrics, property))"
        for property in fieldnames(Metrics)
    ]
    
    return join(values, ", ")
end

struct Warehouse
    location::Location
    installed_capacity::Float64
end

struct Distribution
    warehouse::Warehouse
    customer::Customer
    distribution_amount::Float64
end

struct Solution
    method::Method
    warehouses::Vector{Warehouse}
    distributions::Vector{Distribution}
    model::Union{Model, Nothing}
    metrics::Metrics
end

function summary(solution::Solution)::Vector{DataFrame}
    warehouses = DataFrame(
        location_id = [warehouse.location.ID for warehouse in solution.warehouses],
        installed_capacity = [warehouse.installed_capacity for warehouse in solution.warehouses],
    )
    distributions = DataFrame(
        warehouse_id = [distribution.warehouse.location.ID for distribution in solution.distributions],
        customer_id = [distribution.customer.ID for distribution in solution.distributions],
        distribution_amount = [distribution.distribution_amount for distribution in solution.distributions],
    )
    metrics = DataFrame(
        objective_value = [solution.metrics.objective_value],
        execution_time = [solution.metrics.execution_time],
        expected_recourse = [solution.metrics.expected_recourse],
    )

    return [warehouses, distributions, metrics]
end

function Solution(method::Method, instance::Instance, model::Model, execution_time::Float64)::Solution
    warehouses = [
        Warehouse(location, value(model[:installed_capacity][i]))
        for (i, location) in enumerate(instance.locations)
        if value(model[:is_opened][i]) > 0.5
    ]
    
    amounts = value.(model[:distribution_amount])
    I, J = size(amounts)
    distributions = Distribution[]

    for i in 1:I
        for j in 1:J
            amounts[i, j] > 0 && push!(distributions, Distribution(
                Warehouse(instance.locations[i], value(model[:installed_capacity][i])),
                instance.customers[j],
                amounts[i, j]
            ))
        end
    end

    metrics = Metrics(objective_value = objective_value(model), execution_time = execution_time)

    return Solution(method, warehouses, distributions, model, metrics)
end
