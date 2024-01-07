function solve!(model::Model)::Nothing
    optimize!(model)
    validate(model)
end

function validate(model::Model)::Nothing
    is_optimal = termination_status(model) == MOI.OPTIMAL
    !(is_optimal) && @warn "Model not optimal"

    is_unfeasible = termination_status(model) == MOI.INFEASIBLE_OR_UNBOUNDED
    is_unfeasible && error("Model is unfeasible")

    return nothing
end

str(method::Method)::String = last(split(string(typeof(method)), "."))
