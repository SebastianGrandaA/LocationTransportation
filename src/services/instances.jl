struct Location
    ID::String
    fixed_cost::Float64 # f_i
    capacity_cost::Float64 # a_i
    maximum_capacity::Float64 # C_i / K_i
end

struct UncertainDemand
    base::Real
    deviation::Real
end

struct Customer
    ID::String
    demand::Union{UncertainDemand, Real} # d_j
end

struct Instance
    locations::Vector{Location}
    customers::Vector{Customer}
    transport_cost::Matrix{Float64} # c_ij
    params::Dict{Symbol, Any}
end

"""

Dummy instance
"""
function Instance(; kwargs...)
    params = Dict{Symbol, Any}()
    locations = [
        Location("$(LOCATION_PREFFIX)-1", 400, 18, 800),
        Location("$(LOCATION_PREFFIX)-2", 414, 25, 800),
        Location("$(LOCATION_PREFFIX)-3", 326, 20, 800),
    ]
    transport_cost = [22 33 24; 33 23 30; 20 25 27]

    if haskey(kwargs, :uncertain_demand) && kwargs[:uncertain_demand] == true
        customers = [
            Customer("$(CUSTOMER_PREFFIX)-1", UncertainDemand(206, 40)),
            Customer("$(CUSTOMER_PREFFIX)-2", UncertainDemand(274, 40)),
            Customer("$(CUSTOMER_PREFFIX)-3", UncertainDemand(220, 40)),
        ]
        push!(params, :Γ => [1.8, 1.2])
    else
        customers = [
            Customer("$(CUSTOMER_PREFFIX)-1", 206),
            Customer("$(CUSTOMER_PREFFIX)-2", 274),
            Customer("$(CUSTOMER_PREFFIX)-3", 220)
        ]
    end

    return Instance(locations, customers, transport_cost, params)
end

total_capacity(instance::Instance)::Int64 = sum(location.maximum_capacity for location in instance.locations)
total_demand(instance::Instance)::Int64 = sum(demand(customer.demand) for customer in instance.customers)
nb_locations(instance::Instance)::Int64 = length(instance.locations)
nb_customers(instance::Instance)::Int64 = length(instance.customers)
fixed_cost(instance::Instance, i::Int64)::Float64 = instance.locations[i].fixed_cost
capacity_cost(instance::Instance, i::Int64)::Float64 = instance.locations[i].capacity_cost
maximum_capacity(instance::Instance, i::Int64)::Float64 = instance.locations[i].maximum_capacity
demand(instance::Instance, j::Int64)::Union{UncertainDemand, Real} = instance.customers[j].demand
demand(value::UncertainDemand)::Float64 = value.base + value.deviation
demand(value::Real)::Real = value
demand_base(instance::Instance, j::Int64)::Float64 = demand(instance, j).base
demand_deviation(instance::Instance, j::Int64)::Float64 = demand(instance, j).deviation
transport_cost(instance::Instance, i::Int64, j::Int64)::Float64 = instance.transport_cost[i, j]

is_feasible(instance::Instance)::Bool = total_capacity(instance) >= total_demand(instance)
