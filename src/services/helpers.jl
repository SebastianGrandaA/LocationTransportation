function solve!(model::Model)::Nothing
    optimize!(model)
    validate(model)
end

function validate(model::Model)::Nothing
    to_optimality = termination_status(model) == MOI.OPTIMAL

    !(to_optimality) && @warn "Model not optimal"

    return nothing
end
