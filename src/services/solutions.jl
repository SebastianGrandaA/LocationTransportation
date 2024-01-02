@kwdef mutable struct Metrics
    objective_value::Real = NaN
    execution_time::Real = NaN
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
    warehouse::Warehouse # TODO poner solo los IDS?
    customer::Customer # TODO poner solo los IDS?
    distributed_ammount::Float64
end

struct Solution
    method::Method
    warehouses::Vector{Warehouse}
    distributions::Vector{Distribution}
    model::Model
    metrics::Metrics
end

function Solution(method::Method, instance::Instance, model::Model, execution_time::Float64)::Solution
    warehouses = [
        Warehouse(location, value(model[:installed_capacity][i]))
        for (i, location) in enumerate(instance.locations)
        if value(model[:is_opened][i]) > 0.5
    ]
    distributions = [
        Distribution(warehouse, customer, value(model[:distributed_ammount][i, j]))
        for (i, warehouse) in enumerate(warehouses)
        for (j, customer) in enumerate(instance.customers)
        if value(model[:distributed_ammount][i, j]) > 0
    ]
    metrics = Metrics(objective_value = objective_value(model), execution_time = execution_time)

    return Solution(method, warehouses, distributions, model, metrics)
end