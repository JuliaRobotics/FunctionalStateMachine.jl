module FunctionalStateMachine

using Dates
using Requires
using DocStringExtensions
using ProgressMeter

export
  StateMachine,
  emptyState,
  exitStateMachine,
  sandboxStateMachineStep,
  getStateLabel,
  histStateMachineTransitions


include("StateMachine.jl")

function __init__()
  @require Graphs="86223c79-3864-5bf0-83f7-82e725a168b6" include("StateMachineAnimation.jl")
end

end
