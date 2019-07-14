# FunctionalStateMachine.jl

[![Build Status](https://travis-ci.org/JuliaRobotics/FunctionalStateMachine.jl.svg?branch=master)](https://travis-ci.org/JuliaRobotics/FunctionalStateMachine.jl)
[![codecov.io](https://codecov.io/github/JuliaRobotics/FunctionalStateMachine.jl/coverage.svg?branch=master)](https://codecov.io/github/JuliaRobotics/FunctionalStateMachine.jl?branch=master)

Build a state machine in Julia based on functions along with stepping and visualization tools  


## Video Animation Example

See [Vimeo here for a short video example](https://vimeo.com/341658405) of a three state machine concurrent animation.

# Installation
## [OPTIONAL] System Dependencies
Visualization tools require a system install of `graphviz`.  Do Ubuntu/Debian Linux equivalent of:
```bash
sudo apt-get install graphviz
```

## Install Julia Package
Julia ≥ 0.7 add package
```julia
julia> ]
(v1.0) pkg> add FunctionalStateMachine
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

# no user data struct defined, so just pass Nothing
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
hist = statemachine.history
drawStateMachineHistory(hist, show=true)
```

## Animate Asyncronous State Machine Transitions

The following example function shows several state machines that were run asyncronously can be synchronously animated as separate frames (see below for single frame with multiple information):
```julia
using Dates, DocStringExtensions

"""
    $SIGNATURES

Draw many images in '/tmp/?/csm_%d.png' representing time synchronized state machine
events.

Notes
- State history must have previously been recorded.
"""
function animateStateMachines(histories::Vector{<:Tuple}; frames::Int=100)

  startT = Dates.now()
  stopT = Dates.now()

  # get start and stop times across all cliques
  first = true
  # hist = somestatemachine.history
  for hist in histories
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
  count = 0
  for hist in histories
    count += 1
    retval = animateStateMachineHistoryByTime(hist, frames=frames, folder="sm$count", title="SM-$count", startT=startT, stopT=stopT)
    push!(folders, "sm$count")
  end

  return folders
end

# animate the time via many png images in `/tmp`
animateCliqStateMachines([hist1; hist2], frames=100)
```

This example will result in 100 images for both `hist1, hist` state machine history. Note the timestamps are used to synchronize animations images on concurrent state traversals, and can easily be made into a video with OpenShot or ffmpeg style tools.

## Animate Multiple State Machines Together

A closely related function
```julia
animateStateMachineHistoryByTime
```
can combine multiple concurrent histories of the state machine execution into the same image frames.  See function for more details.

# Contribute

Contributions and Issues welcome.
