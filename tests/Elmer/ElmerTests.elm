module Elmer.ElmerTests exposing (all)

import Test exposing (..)
import Elmer.TestApps.SimpleTestApp as SimpleApp
import Elmer.TestApps.InitTestApp as InitApp
import Elmer.TestHelpers exposing (..)
import Expect
import Elmer exposing (..)
import Elmer.Internal as Internal exposing (..)
import Elmer.Html
import Elmer.Html.Matchers as Matchers
import Elmer.Spy as Spy
import Elmer.Platform.Command as Command
import Elmer.Http
import Elmer.Http.Matchers as HttpMatchers
import Elmer.Printer exposing (..)
import Task

all : Test
all =
  describe "Elmer Tests"
    [ mapToExpectationTests
    , initTests
    , matchAllTests
    , matchOneTests
    , hasSizeTests
    , expectNotTests
    , andThenTests
    , expectModelTests
    ]

mapToExpectationTests =
  describe "mapToExpectaion"
  [ describe "when there is an upstream error"
    [ test "it fails with the upstream error" <|
      \() ->
        Internal.mapToExpectation (\_ -> Expect.pass) (Failed "Failed!")
          |> Expect.equal (Expect.fail "Failed!")
    ]
  , describe "when there is no upstream failure"
    [ describe "when the mapper fails"
      [ test "it fails" <|
        \() ->
          let
            initialState = Elmer.componentState SimpleApp.defaultModel SimpleApp.view SimpleApp.update
          in
            Internal.mapToExpectation (\_ -> Expect.fail "I failed!") initialState
              |> Expect.equal (Expect.fail "I failed!")
      ]
    , describe "when the mapper passes"
      [ test "it passes" <|
        \() ->
          let
            initialState = Elmer.componentState SimpleApp.defaultModel SimpleApp.view SimpleApp.update
          in
            Internal.mapToExpectation (
              \componentState ->
                Expect.equal Nothing componentState.targetSelector
            ) initialState
              |> Expect.equal (Expect.pass)
      ]
    ]
  ]

initTests : Test
initTests =
  describe "init"
  [ describe "when there is a faiure"
    [ test "it fails" <|
      \() ->
        let
          initialState = Failed "You failed!"
        in
          Elmer.init (\() -> (InitApp.defaultModel "", Cmd.none)) initialState
            |> Expect.equal (Failed "You failed!")
    ]
  , let
      state = Elmer.componentState (InitApp.defaultModel "") InitApp.view InitApp.update
        |> Spy.use [ Elmer.Http.spy ]
        |> Elmer.init (\() -> InitApp.init { baseUrl = "http://fun.com/api" })
    in
      describe "when there is no failure"
      [ test "it sets the model" <|
        \() ->
          state
            |> Elmer.Html.find "#base-url"
            |> Elmer.Html.expectElement (Matchers.hasText "http://fun.com/api")
      , test "it sends the command" <|
        \() ->
          state
            |> Elmer.Http.expectGET "http://fun.com/api/token" HttpMatchers.wasSent
      ]
  , describe "when the command fails"
    [ test "it fails" <|
      \() ->
        let
          state = Elmer.componentState (InitApp.defaultModel "") InitApp.view InitApp.update
            |> Elmer.init (\() -> (InitApp.defaultModel "", Task.perform InitApp.Tag (Task.succeed "Yo")) )
        in
          case state of
            Ready _ ->
              Expect.fail "Should have failed!"
            Failed message ->
              Expect.equal True <|
                String.contains "Elmer encountered a command it does not know how to run" message
    ]
  ]

matchAllTests : Test
matchAllTests =
  describe "each"
  [ describe "when all items match"
    [ test "it passes" <|
      \() ->
        let
          items = [ 2, 4, 6, 8, 10 ]
        in
          each (\n -> Expect.equal (n % 2) 0) items
            |> Expect.equal Expect.pass
    ]
  , describe "when one item fails to match"
    [ test "it fails" <|
      \() ->
        let
          items = [ 2, 4, 5, 6, 8, 10]
        in
          each (\n -> Expect.equal (n % 2) 0) items
            |> Expect.equal (Expect.fail (format [ message "An item failed to match" "0\n╷\n│ Expect.equal\n╵\n1" ]))
    ]
  ]

matchOneTests : Test
matchOneTests =
  describe "some"
    [ describe "when no items match"
      [ test "it fails" <|
        \() ->
          let
            items = [ 2, 4, 6, 8, 10 ]
          in
            some (\n -> Expect.equal (n % 17) 0) items
              |> Expect.equal (Expect.fail "No items matched")
      ]
    , describe "when one item matches"
      [ test "it passes" <|
        \() ->
          let
            items = [ 2, 4, 5, 17, 8, 10]
          in
            some (\n -> Expect.equal (n % 17) 0) items
              |> Expect.equal Expect.pass
      ]
    ]

hasSizeTests : Test
hasSizeTests =
  describe "hasSize"
  [ describe "when the list has the expected size"
    [ test "it passes" <|
      \() ->
        let
          items = [ 2, 4, 6, 8, 10 ]
        in
          hasSize 5 items
            |> Expect.equal Expect.pass
    ]
  , describe "when the list does not have the expected size"
    [ test "it fails" <|
      \() ->
        let
          items = [ 2, 4, 6, 8, 10 ]
        in
          hasSize 3 items
            |> Expect.equal (Expect.fail (format [ message "Expected list to have size" "3", message "but it has size" "5"]))
    ]
  ]

expectNotTests : Test
expectNotTests =
  describe "expectNot"
  [ describe "when the matcher passes"
    [ test "it fails" <|
      \() ->
        (nodeWithClassAndId "myClass" "myId")
          |> Elmer.expectNot (Matchers.hasId "myId")
          |> Expect.equal (Expect.fail "Expected not to be the case but it is")
    ]
  , describe "when the matcher fails"
    [ test "it passes" <|
      \() ->
        (nodeWithClassAndId "myClass" "myId")
          |> (Elmer.expectNot <| Matchers.hasId "someWrongId")
          |> Expect.equal Expect.pass
    ]
  ]

andThenTests : Test
andThenTests =
  describe "andThen"
  [ describe "when all matchers pass"
    [ test "it passes" <|
      \() ->
        (nodeWithClassAndId "myClass" "myId") |>
          Matchers.hasId "myId"
            <&&> Matchers.hasClass "myClass"
            <&&> Matchers.hasClass "funClass"
    ]
  , describe "when the first matcher fails"
    [ test "it fails with the first failure" <|
      \() ->
        (nodeWithClass "myClass")
          |> (Matchers.hasId "root"
                <&&> Matchers.hasClass "myClass")
          |> Expect.equal (Expect.fail "Expected node to have id\n\n\troot\n\nbut it has no id")
    ]
  , describe "when the second matcher fails"
    [ test "it fails with the second failure" <|
      \() ->
        (nodeWithId "root")
          |> (Matchers.hasId "root"
                <&&> Matchers.hasClass "myClass")
          |> Expect.equal (Expect.fail "Expected node to have class\n\n\tmyClass\n\nbut it has no classes")
    ]
  ]

expectModelTests : Test
expectModelTests =
  describe "expectModel"
  [ describe "when there is a failure upstream"
    [ test "it fails" <|
      \() ->
        let
          initialState = Failed "You failed!"
        in
          Elmer.expectModel (\model -> Expect.fail "Shouldn't get here") initialState
            |> Expect.equal (Expect.fail "You failed!")
    ]
  , describe "when there is no failure"
    [ test "it runs the matcher on the current model" <|
      \() ->
        Elmer.componentState SimpleApp.defaultModel SimpleApp.view SimpleApp.update
          |> Elmer.expectModel (\model ->
            Expect.equal model.name "Cool Person"
          )
          |> Expect.equal Expect.pass
    ]
  ]
