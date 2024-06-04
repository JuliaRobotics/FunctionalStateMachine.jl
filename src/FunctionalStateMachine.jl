module FunctionalStateMachine

using Dates
using Requires
using DocStringExtensions
using ProgressMeter

export
  StateMachine,
  emptyState,
  exitStateMachine,
  getIterCount,
  sandboxStateMachineStep,
  getStateLabel,
  histStateMachineTransitions


include("StateMachine.jl")
# FIXME Graphs here was the old Graphs.jl and needs to be updated to the new Graphs.jl (previously LightGraphs.jl)
include("WeakdepsPrototypes.jl")

end
