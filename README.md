# FunctionalStateMachine.jl

[![CI](https://github.com/JuliaRobotics/FunctionalStateMachine.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaRobotics/FunctionalStateMachine.jl/actions/workflows/CI.yml)
[![codecov.io](https://codecov.io/github/JuliaRobotics/FunctionalStateMachine.jl/coverage.svg?branch=master)](https://codecov.io/github/JuliaRobotics/FunctionalStateMachine.jl?branch=master)

[![Average time to resolve an issue](https://isitmaintained.com/badge/resolution/JuliaRobotics/FunctionalStateMachine.jl.svg)](https://github.com/JuliaRobotics/FunctionalStateMachine.jl/issues)
[![Percentage of issues still open](https://isitmaintained.com/badge/open/JuliaRobotics/FunctionalStateMachine.jl.svg)](https://github.com/JuliaRobotics/FunctionalStateMachine.jl/issues)

Build a state machine in Julia based on functions along with stepping and visualization tools  


## Video Animation Example

Click the Vimeo image as link to a FSM generated video animation of six concurrent state machines (as used in [IncrementalInference.jl](http://www.github.com/JuliaRobotics/IncrementalInference.jl)).

[![Clique State Machine Concurrent Animation](https://user-images.githubusercontent.com/6412556/92198487-87b10900-ee42-11ea-8674-4a3867a74b65.png)](https://vimeo.com/454616769 "Clique State Machine Concurrent Animation - Click to Watch!")

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
(v1.5) pkg> add FunctionalStateMachine
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

### Watchdog Timeout

Sometimes it is useful to know that an FSM process will exit, either as intended or by throwing an error on timeout (much like a [Watchdog Timer](https://en.wikipedia.org/wiki/Watchdog_timer)).  FSM uses Base.`InterruptException()` as a method of stopping a task that expires a `timeout::Real` [seconds].  Note, this functionality is not included by default in order to preserve a small memory footprint.  To use the timeout feature simply call the state machine with a timeout duration:
```julia
userdata = nothing # any user data of type T
timeout = 3.0
while statemachine(userdata, timeout, verbose=true); end
```

### Recording Verbose Output to File

Experience has shown that when a state machine gets stuck, it is often useful to write the `verbose` steps out to file as a bare minimum guide of where a system might be failing.  This can be done by passing in a `::IOStream` handle into `verbosefid`:
```julia
fid = open("/tmp/verboseFSM_001.log","w")
while statemachine(userdata, verbose=true, verbosefid=fid); end
close(fid)
```

This particular structure is chosen so that `@async` or other multithreaded uses of FSM can still write to a common `fid` and also allow the user to `flush(fid)` and `close(fid)` regardless of whether the FSM has stalled.  Might seem "boilerplate-esque", but it's much easier for developers to snuff out bugs in highly complicted interdependent and multithreaded, multi-state-machine architectures.

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

## Multiple state machines can be visualized together
```julia
using Graphs, FunctionalStateMachine

#...

# start multiple concurrent FSMs (this is only one)
## they are likely interdependent
statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, recordhistory=true); end

# add all histories to the `hists::Dict` as follows
## ths example has userdata of type ::Nothing
hists = Dict{Symbol,Vector{Tuple{DateTime,Int,Function,Nothing}}}(:first => statemachine.history)

# generate all the images that will make up the video
animateStateMachineHistoryIntervalCompound(hists, interval=1)

# and convert images to video with ffmpeg as shell command
fps = 5
run(`ffmpeg -r 10 -i /tmp/caesar/csmCompound/csm_%d.png -c:v libtheora -vf fps=$fps -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -q 10 /tmp/caesar/csmCompound/out.ogv`)
@async run(`totem /tmp/caesar/csmCompound/out.ogv`)
```
can combine multiple concurrent histories of the state machine execution into the same image frames.  See function for more details.


# Lower Level Visualization tools

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

## Previous Linear Time Multi-FSM Animation

A closely related function
```julia
animateStateMachineHistoryByTime
```


# Contribute

Contributions and Issues welcome.
