"""
    solve(::ConstraintGeneration)

Iterative multi-cut dynamic constraint generation.
Once this first-stage decisions are made, we solve the subproblem (SP) for each customer to determine the transportation quantities from the warehouses to the customers.
"""
function solve(method::ConstraintGeneration, instance::Instance, solver::SOLVER)::Solution
    start_time, iteration = time(), 1

    # Initialize master problem
    master = MasterProblem(instance, solver)

    # Obtain robust demand
    robust_demand = UncertaintySet(instance, solver).demand

    while should_continue(iteration)
        @info "$(str(method)) | Iteration $iteration"

        solve!(master)
        register_cuts!(master, instance, solver, robust_demand)
        add_cuts!(master, instance, iteration)

        iteration += 1
    end

    solve!(master)
    @info "$(str(method)) | History" master.history

    return Solution(method, instance, master, time() - start_time)
end

function should_continue(iteration::Int64)::Bool
    return iteration <= MAXIMUM_ITERATIONS
end

"""
    register_cuts!(::MasterProblem)

Find new cuts for each customer in parallel and register them in the master problem.
"""
function register_cuts!(master::MasterProblem, instance::Instance, solver::SOLVER, robust_demand::Vector{Float64})::Nothing
    optimality_type, feasibility_type = Optimality(), Feasibility()
    tasks = []
    locations = 1:nb_locations(instance)
    nworkers() < last(locations) && addprocs(min(last(locations) - nworkers(), 10))
    
    for i in locations
        task = @async begin
            subproblems = ProblemType[]

            feasibility = SubProblem(feasibility_type, solver, instance, master, i, robust_demand)
            is_infeasible = !(isnothing(feasibility))
            is_infeasible && push!(subproblems, feasibility)

            optimality = SubProblem(optimality_type, solver, instance, master, i, robust_demand)
            is_feasible = !(isnothing(optimality))
            (is_feasible && has_improved(optimality, master)) && push!(subproblems, optimality)

            return subproblems
        end

        push!(tasks, task)
    end

    for task in tasks
        subproblems = fetch(task)
        cuts = [subproblem.cut for subproblem in subproblems]

        push!(master.cuts, cuts)
    end

    rmprocs(workers())
    
    return nothing
end

"""
    add_cuts!(::MasterProblem)

Add registered cuts to the master problem.
"""
function add_cuts!(master::MasterProblem, instance::Instance, iteration::Int64)
    locations = 1:nb_locations(instance)
    
    for i in locations
        to_add = master.cuts[i]
        @debug " | Iteration $(iteration) | Location $(i) | Cuts to add" to_add

        for cut in to_add
            is_optimality_cut = !(isnan(cut.objective_value)) # consider only optimality cuts
            master.metrics.expected_recourse += is_optimality_cut ? cut.objective_value : 0

            add_cut!(cut.type, master, cut.expression, i)
            @debug " | Iteration $(iteration) | Location $(i) | Cut : $(cut)"
        end
    end

    master.cuts = [] # reset cuts
end

function Solution(method::ConstraintGeneration, instance::Instance, master::MasterProblem, execution_time::Float64)::Solution
    warehouses = [
        Warehouse(location, value(master.model[:installed_capacity][i]))
        for (i, location) in enumerate(instance.locations)
        if value(master.model[:is_opened][i]) > 0.5
    ]
    distributions = [
        Distribution(warehouse, customer, value(master.model[:θ][i]))
        for (i, warehouse) in enumerate(warehouses)
        for (_, customer) in enumerate(instance.customers)
        if value(master.model[:θ][i]) > 0
    ]
    metrics = Metrics(
        objective_value = objective_value(master.model),
        execution_time = execution_time,
    )

    return Solution(method, warehouses, distributions, master.model, metrics)
end

function has_improved(subproblem::SubProblem, master::MasterProblem)::Bool
    return true
end