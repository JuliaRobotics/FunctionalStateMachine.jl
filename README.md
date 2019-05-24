# FunctionalStateMachine.jl

[![Build Status](https://travis-ci.org/JuliaRobotics/FunctionalStateMachine.jl.svg?branch=master)](https://travis-ci.org/JuliaRobotics/FunctionalStateMachine.jl)
[![codecov.io](https://codecov.io/github/JuliaRobotics/FunctionalStateMachine.jl/coverage.svg?branch=master)](https://codecov.io/github/JuliaRobotics/FunctionalStateMachine.jl?branch=master)

Build a state machine in Julia based on functions along with stepping and visualization tools  

# Installation
## [OPTIONAL] System Dependencies
Visualization tools require a system install of `graphviz`.  Do Ubuntu/Debian Linux equivalent of:
```bash
sudo apt-get install graphviz
```

## Install Julia Package
Julia ≥ 0.7 add package (currently unregistered)
```julia
]dev https://github.com/JuliaRobotics/FunctionalStateMachine.jl.git
```

# Example

## Basic
```julia
using FunctionalStateMachine

## User state functions
function bar!(usrdata)
  println("do bar!")
  return FunctionalStateMachine.exitStateMachine
end

function foo!(usrdata)
  println("do foo!")
  return bar!
end

# no user data struct defined, so just passing Nothing
statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, verbose=true); end

# or maybe limit number of steps
statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, iterlimit=1); end
```

## With User Data and History

```julia
## Passing a data structure
mutable struct ExampleUserData
  x::Vector{Float64}
end

# or maybe record the state machine history
statemachine = StateMachine{ExampleUserData}(next=foo!)
eud = ExampleUserData(randn(10))
while statemachine(eud, recordhistory=true); end

# recover recorded state transition history, `::Vector{Tuple{DateTime,Int,Function,T}}`
hist = statemachine.history

# or maybe rerun a step on the data as it was at that time -- does not overwrite previous memory
new_eud_at_1 = sandboxStateMachineStep(hist, 1)
```

## Draw State Pictures with Graphviz

```julia
# ]add Graphs # in case the dependency is not installed yet

using Graphs

# run the state machine
statemachine = StateMachine{ExampleUserData}(next=foo!)
eud = ExampleUserData(randn(10))
while statemachine(eud, recordhistory=true); end

# draw the state machine
drawStateMachineHistory(hist, show=true)
```

## Animate Asyncronous State Machine Transitions

The following example function shows several state machines that were run asyncronously can be synchronously animated:
```julia
"""
    $SIGNATURES

Draw many images in '/tmp/?/csm_%d.png' representing time synchronized state machine
events for cliques `cliqsyms::Vector{Symbol}`.

Notes
- State history must have previously been recorded (stored in tree cliques).
"""
function animateCliqStateMachines(tree::BayesTree, cliqsyms::Vector{Symbol}; frames::Int=100)

  startT = Dates.now()
  stopT = Dates.now()

  # get start and stop times across all cliques
  first = true
  for sym in cliqsyms
    hist = getCliqSolveHistory(tree, sym)
    if hist[1][1] < startT
      startT = hist[1][1]
    end
    if first
      stopT = hist[end][1]
    end
    if stopT < hist[end][1]
      stopT= hist[end][1]
    end
  end

  # export all figures
  folders = String[]
  for sym in cliqsyms
    hist = getCliqSolveHistory(tree, sym)
    retval = animateStateMachineHistoryByTime(hist, frames=frames, folder="cliq$sym", title="$sym", startT=startT, stopT=stopT)
    push!(folders, "cliq$sym")
  end

  return folders
end

# animate the time many png images in `/tmp/statemachine`
animateCliqStateMachines(tree, [:x1;:x3], frames=100)
```

This example will result in 100 images for both the `:x1` and `:x3` state machines, but note the timestamps are synchronized -- therefore, animations on concurrent state traversal can easily be made with OpenShot or ffmpeg style tools.
