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

#FIXME Graphs here was the old Graphs.jl and needs to be updated to the new Graphs.jl (previously LightGraphs.jl)
# function __init__()
#   @require Graphs="86223c79-3864-5bf0-83f7-82e725a168b6" include("StateMachineAnimation.jl")
# end

end
