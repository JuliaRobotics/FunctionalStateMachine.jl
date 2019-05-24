
using FunctionalStateMachine
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


#
