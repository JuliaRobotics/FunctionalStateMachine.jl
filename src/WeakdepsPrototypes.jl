
export
  histGraphStateMachineTransitions,
  drawStateTransitionStep,
  drawStateMachineHistory,
  animateStateMachineHistoryByTime,
  animateStateMachineHistoryByTimeCompound,
  animateStateMachineHistoryIntervalCompound

"""
    $SIGNATURES

Create a `Graphs.incdict` object and populate with nodes (states) and edges (transitions)
according to the contents of parameters passed in.

Notes:
- Current implementation repeats duplicate transitions as new edges.
"""
function histGraphStateMachineTransitions end

function renderStateMachineFrame end
function setVisGraphOnState! end
function drawStateTransitionStep end
function drawStateMachineHistory end

"""
    $SIGNATURES

Draw simultaneously separate time synchronized frames from each of the desired
state machines.  These images can be produced into synchronous side-by-side videos
which allows for easier debugging and comparison of concurrently running state
machines.
"""
function animateStateMachineHistoryByTime end

function animateStateMachineHistoryByTimeCompound end
function getTotalNumberSteps end
function getFirstStepHist end
function getNextStepHist! end
function animateStateMachineHistoryIntervalCompound end

