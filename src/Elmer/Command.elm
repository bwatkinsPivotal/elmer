module Elmer.Command exposing
  ( fail
  , fake
  , defer
  , dummy
  , expectDummy
  , send
  , given
  , expectMessages
  )

{-| Functions for dealing with commands during your tests.

Elmer allows you to manage the effects of commands yourself, so you can
describe the behavior of a component under whatever conditions you need.

To manage the effects of a command, you'll need to do two things.

1. Stub the function in your code that produces the command and replace
it with a function that returns one of the fake commands described below.

2. Enjoy.

Note: Elmer supports `Platform.Cmd.batch` and `Platform.Cmd.map` so you can use these in your
component as expected.

Note: Elmer provides special support for commands generated by
[elm/http](http://package.elm-lang.org/packages/elm/http/latest)
and [elm/browser](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation)
-- See `Elmer.Http` and `Elmer.Navigation`, respectively.

# Fake Commands
@docs fake, dummy, expectDummy, fail

# Defer a Command
@docs defer

# Send a Fake Command
@docs send

# Test a Command
@docs given, expectMessages

-}

import Elmer exposing (Matcher)
import Elmer.TestState as TestState exposing (TestState)
import Elmer.Context as Context exposing (Context)
import Elmer.Runtime as Runtime
import Elmer.Message exposing (..)
import Elmer.Runtime.Command as RuntimeCommand
import Elmer.Runtime.Command.Defer as Defer
import Elmer.Command.Internal exposing (CommandState(..), testStateWithCommand)
import Expect


{-| Generate a command that will cause the test to fail with the specified message.
-}
fail : String -> Cmd msg
fail =
  RuntimeCommand.fail

{-| Generate a command that returns a message.

When this command is processed, the message will be passed
to the component's `update` function.
-}
fake : msg -> Cmd msg
fake =
  RuntimeCommand.stub

type CommandState
  = DummyCommands


{-| Generate a dummy command.

You might only care to describe the fact that a command has been sent, and not
the behavior that may result from its effect. In that case, use a dummy command.

When this command is processed, the fact that it occured will be
recorded; no message will be passed to the component's `update` function.
This will be most useful in conjunction with `expectDummy`.
-}
dummy : String -> Cmd msg
dummy identifier =
  RuntimeCommand.mapState DummyCommands <|
    updateStateWithDummyCommand identifier


updateStateWithDummyCommand : String -> Maybe (List String) -> List String
updateStateWithDummyCommand identifier state =
  Maybe.withDefault [] state
    |> (::) identifier


{-| Expect that a dummy command with the given identifier has been sent.
-}
expectDummy : String -> Matcher (Elmer.TestState model msg)
expectDummy expectedIdentifier =
  TestState.mapToExpectation <|
    \context ->
      let
        matchingCommands =
          Context.state DummyCommands context
            |> Maybe.withDefault []
            |> List.filter (\identifier -> identifier == expectedIdentifier)
      in
        if List.isEmpty matchingCommands then
          Expect.fail (format [fact "No dummy commands sent with identifier" expectedIdentifier])
        else
          Expect.pass


{-| Defer a command for later processing.

You might want to describe the behavior that occurs after a command
is sent but before its effect is processed -- for example, the component could
indicate that network activity is occurring while waiting for a request to complete.

When a deferred command is processed, any effect associated with that command will *not* be sent
to the component's `update` function until `Elmer.resolveDeferred` is called.
-}
defer : Cmd msg -> Cmd msg
defer =
  Defer.with


{-| Send a command.

Use this function to send a command to your program. Any effect associated with this
command will be processed accordingly. Elmer only knows how to process the fake commands
described above.

The first argument is a function that returns the command to be sent.
We do this to allow Elmer to evaluate the command-generating function lazily,
in case any stubbed functions need to be applied.

    testState
      |> send (\() -> 
          MyModule.generateSomeCommand
        )
      |> Elmer.Html.target 
          << by [ class "some-class" ]
      |> Elmer.Html.expect 
          Elmer.Html.Matchers.elementExists

-}
send : (() -> Cmd msg) -> Elmer.TestState model msg -> Elmer.TestState model msg
send commandThunk =
  TestState.map (\state ->
    Runtime.performCommand (commandThunk ()) state
      |> TestState.fromRuntimeResult
  )


{-| Initialize a `TestState` with a command.

A test initialized in this way can use `expectMessages` to examine
messages generated when the given command is processed.
-}
given : (() -> Cmd msg) -> TestState () msg
given =
  testStateWithCommand

{-| Make expectations about messages generated by processing a command.

    Elmer.Command.given (\() -> 
        MyModule.commandToSendAnHttpRequest someArg
    )
      |> Elmer.Spy.use 
          [ Elmer.Http.serve [ someStubbedResponse ] ]
      |> Elmer.expectMessages (
        exactly 1 <| Expect.equal (
          MyMessage <| 
            Ok "response from server"
        )
      )

Note that `expectMessages` should only be used in a test initialized
with `Elmer.Command.given`.
-}
expectMessages : Matcher (List msg) -> Matcher (TestState () msg)
expectMessages matcher =
  TestState.mapToExpectation <|
    \context ->
      Context.state Messages context
        |> Maybe.withDefault []
        |> matcher
