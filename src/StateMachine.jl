
"""
    $TYPEDEF

Generic state machine functor type.

Example
```julia
bar!(usrdata) = IncrementalInference.exitStateMachine
foo!(usrdata) = bar!

sm = StateMachine(next=foo!)
usrdata = nothing
while st(usrdata); end
```

Notes
- Also see IncrementalInference/test/testStateMachine.jl
"""
mutable struct StateMachine{T}
  next::Function
  iter::Int
  history::Vector{Tuple{DateTime, Int, Function, T}}
  name::String
  StateMachine{T}(;next=emptyState, iter::Int=0, name::AbstractString="") where T = new{T}(next, iter, Vector{Tuple{DateTime, Int, Function, T}}(), name)
end



"""
    $SIGNATURES

Run state machine function (as functor).

Notes
- `timeout::Union{Real,Nothing}` is optional with default `=nothing`.
  - this code is skipped in lowered and llvm code if not used
  - subroutine will use `pollinterval::Real` [seconds] to interrogate during `timeout::Real` [seconds] period.
- can stop FSM early by using any of the following:
  - `breakafter`, `iterlimit`.
- Can `injectDelayBefore` a function `st.next` to help with debugging.
- can print FSM steps with `verbose=true`.
  - `verbosefid::IOStream` is used as destination for verbose output, default is `stdout`.
- FSM steps and `userdata` can be recorded in standard `history` format using `recordhistory=true`.
- `housekeeping_cb` is callback to give user access to `StateMachine` internals and opportunity to insert bespoke operations.

Example
```julia
bar!(usrdata) = IncrementalInference.exitStateMachine
foo!(usrdata) = bar!

sm = StateMachine(next=foo!)
usrdata = nothing
while st(usrdata); end
```
"""
function (st::StateMachine{T})( userdata::T=nothing,
                                timeout::Union{Nothing,<:Real}=nothing;
                                pollinterval::Real=0.05,
                                breakafter::Function=exitStateMachine,
                                verbose::Bool=false,
                                verbosefid=stdout,
                                iterlimit::Int=-1,
                                injectDelayBefore::Union{Nothing,Pair{<:Function, <:Real}}=nothing,
                                recordhistory::Bool=false,
                                housekeeping_cb::Function=(st)->()  ) where {T}
  #
  st.iter += 1
  # verbose print to help debugging
  !verbose ? nothing : println(verbosefid, "FSM $(st.name), iter=$(st.iter) -- $(st.next)")
  # early exit plumbing
  retval = st.next != breakafter && (iterlimit == -1 || st.iter < iterlimit)
  # record steps for later
  T0 = Dates.now()
  recordhistory ? push!(st.history, (T0, st.iter, deepcopy(st.next), deepcopy(userdata))) : nothing
  # user has some special situation going on.
  housekeeping_cb(st)
  (injectDelayBefore !== nothing && injectDelayBefore[1] == st.next) ? sleep(injectDelayBefore[2]) : nothing
  if timeout === nothing
    # no watchdog, just go and optimize llvm lowered code
    st.next = st.next(userdata)
  else
    # add the watchdog into the llvm lowered code
    currtsk = current_task()
    # small amount of memory usage, but must guarantee InterruptException is not accidently fired during next step.
    doneWatchdog = Base.RefValue{Int}(0) 
    wdt = @async begin
      # wait for watchdog timeperiod in a seperate co-routine
      res = timedwait(()->doneWatchdog[]==1, timeout, pollint=pollinterval)
      # Two requirements needed to interrupt FSM step
      res == :timed_out && doneWatchdog[] == 0 ? schedule(currtsk, InterruptException(), error=true) : nothing
    end
    st.next = st.next(userdata)
    doneWatchdog[] = 1
  end
  return retval
end

"""
    $SIGNATURES

Dummy function in case a `statemachine.next` is not initialized properly.
"""
function emptyState(dummy)
  @warn "Empty state machine, assign `next` to entry function -- i.e. StateMachine(next=foo)"
  return exitStateMachine
end

"""
    $SIGNATURES

Default function used for exiting any state machine.
"""
function exitStateMachine(dummy)
  return emptyState
end

"""
    $SIGNATURES

How many iterations has this `::StateMachine` stepped through.
"""
getIterCount(st::StateMachine) = st.iter

"""
  $SIGNATURES

Repeat a state machine step without changing history or primary values.
"""
function sandboxStateMachineStep(hist::Vector{Tuple{DateTime, Int, <:Function, T}},
                                 step::Int  ) where T
  #
  usrdata = deepcopy(hist[step][4])
  @time nextfnc = hist[step][3](usrdata)
  return (hist[step][1], step+1, nextfnc, usrdata)
end


getStateLabel(state) = Symbol(split(split(string(state), '_')[1],'.')[end])


function histStateMachineTransitions(hist::T;
                                     allStates=Vector{Symbol}(),
                                     stateVisits = Dict{Symbol, Vector{Symbol}}() ) where {T <: Array}
  # local memory

  # find all states and transitions and add as outgoing vector of edges from state lbl
  for i in 1:(length(hist)-1)
    sta  = string(hist[i][3])
    lbl = getStateLabel(sta)
    nsta = string(hist[i+1][3])
    nlbl = getStateLabel(nsta)
    if !haskey(stateVisits, lbl)
      stateVisits[lbl] = Symbol[nlbl;]
    else
      push!(stateVisits[lbl], nlbl)
    end
    union!(allStates, [lbl; nlbl])
  end

  return stateVisits, allStates
end

#
