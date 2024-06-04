
using FunctionalStateMachine
using Graphs
using Dates
using Test

## User state functions

function bar!(usrdata)
  println("do bar!")
  return FunctionalStateMachine.exitStateMachine
end

function foo!(usrdata)
  println("do foo!")
  return bar!
end


@testset "Test generic state machine..." begin

statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, verbose=true); end

@test statemachine.next == emptyState


statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, verbose=false); end

@test statemachine.next == emptyState


statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, breakafter=foo!); end

@test statemachine.next == bar!


statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, iterlimit=1); end

@test statemachine.next == bar!


statemachine = StateMachine{Nothing}(next=bar!)
while statemachine(nothing, verbose=true); end

@test statemachine.next == emptyState


end


@testset "test watchdog timeout" begin

function longwait(x)
  @info "starting stagnant function call, but should not see it's end (but watchdog timeout)"
  while true 
    print(".")
    sleep(0.5)
  end
  @info "done with longwait"
  return exitStateMachine
end

statemachine = StateMachine{Nothing}(next=longwait)
try
  while statemachine(nothing, 2.0, verbose=true); end
catch e
  @info " watchdog test, successfully caught exception for stagnant FSM step"
  @test_throws InterruptException throw(e)
end

end


@testset "test recording and rendering of an FSM run" begin

statemachine = StateMachine{Nothing}(next=foo!)
while statemachine(nothing, recordhistory=true); end

hists = Dict{Symbol,Vector{Tuple{DateTime,Int,Function,Nothing}}}(:first => statemachine.history)

@error "Restore weakdeps animateStateMa... test"
@test_broken false
# animateStateMachineHistoryIntervalCompound(hists, interval=1)

end

#
