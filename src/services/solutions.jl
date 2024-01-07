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

function Solution(method::Method, instance::Instance, model::Model, execution_time::Float64)::Solution
    warehouses = [
        Warehouse(location, value(model[:installed_capacity][i]))
        for (i, location) in enumerate(instance.locations)
        if value(model[:is_opened][i]) > 0.5
    ]
    distributions = [
        Distribution(warehouse, customer, value(model[:distribution_amount][i, j]))
        for (i, warehouse) in enumerate(warehouses)
        for (j, customer) in enumerate(instance.customers)
        if value(model[:distribution_amount][i, j]) > 0
    ]
    metrics = Metrics(objective_value = objective_value(model), execution_time = execution_time)

    return Solution(method, warehouses, distributions, model, metrics)
end
