module Elmer.SubscriptionTests exposing (..)

import Test exposing (..)
import Expect
import Elmer
import Elmer.TestState as TestState exposing (..)
import Elmer.Spy as Spy
import Elmer.Subscription as Subscription
import Elmer.Message exposing (..)
import Elmer.Html as Markup
import Elmer.Html.Matchers as Matchers exposing (element, hasText)
import Elmer.Html.Selector as Sel exposing (..)
import Elmer.TestApps.SubscriptionTestApp as App
import Time


all : Test
all =
  Test.concat
  [ withTests
  , sendTests
  ]


withTests : Test
withTests =
  describe "with"
  [ describe "when there is an upstream failure"
    [ test "it fails" <|
      \() ->
        let
          initialState = TestState.failure "You Failed!"
        in
          Subscription.with (\() _ -> Sub.none) initialState
            |> Expect.equal (TestState.failure "You Failed!")
    ]
  ]

sendTests : Test
sendTests =
  describe "Subscription.send"
  [ describe "when there is an upstream failure"
    [ test "it fails" <|
      \() ->
        let
          initialState = TestState.failure "You Failed!"
        in
          Subscription.send "mySub" 37 initialState
            |> Expect.equal (TestState.failure "You Failed!")
    ]
  , describe "when no subscription is found"
    [ describe "when there are no subscriptions spies"
      [ test "it fails and explains why" <|
        \() ->
          let
            initialState = Elmer.given App.defaultModel App.view App.update
          in
            Subscription.send "someOtherSub" 37 initialState
              |> Expect.equal (TestState.failure (
                format
                  [ fact "No subscription spy found with name" "someOtherSub"
                  , note "because there are no subscription spies"]
                ))
      ]
    , describe "when there are subscription spies"
      [ test "it fails and lists the spies" <|
        \() ->
          let
            override =
              Spy.observe (\_ -> Time.every)
                |> Spy.andCallFake (\interval tagger ->
                  Subscription.fake ("my-spy-" ++ (String.fromFloat interval)) tagger
                )
          in
            Elmer.given App.defaultModel App.view App.update
              |> Spy.use [ override ]
              |> Subscription.with (\() -> App.mappedSubscriptions)
              |> Subscription.send "someOtherSub" 37
              |> Expect.equal (TestState.failure (
                format
                  [ fact "No subscription spy found with name" "someOtherSub"
                  , fact "These are the current subscription spies" "my-spy-3600000\nmy-spy-1"
                  ]
                ))
      ]
    ]
  , describe "when the subscription is found"
    [ describe "when the subscription is a single Sub"
      [ test "the data is tagged and processed" <|
        \() ->
          let
            override =
              Spy.observe (\_ -> Time.every)
                |> Spy.andCallFake (\interval tagger ->
                  Subscription.fake ("fakeTime-" ++ (String.fromFloat interval)) tagger
                )
          in
            Elmer.given App.defaultModel App.view App.update
              |> Spy.use [ override ]
              |> Subscription.with (\() -> App.subscriptions)
              |> Subscription.send "fakeTime-1000" (Time.millisToPosix 23000)
              |> Markup.target << by [ id "time" ]
              |> Markup.expect ( element <| hasText "23 seconds" )
      ]
    , describe "when the subscription is a batch of Subs"
      [ test "the data is tagged and processed" <|
        \() ->
          let
            initialState = Elmer.given App.defaultModel App.view App.update
            override =
              Spy.observe (\_ -> Time.every)
                |> Spy.andCallFake (\interval tagger ->
                  Subscription.fake ("fakeTime-" ++ (String.fromFloat interval)) tagger
                )
          in
            Spy.use [ override ] initialState
              |> Subscription.with (\() -> App.batchedSubscriptions)
              |> Subscription.send "fakeTime-60000" (Time.millisToPosix (1000 * 60 * 37))
              |> Markup.target << by [ id "minute" ]
              |> Markup.expect ( element <| hasText "37 minutes" )
      ]
    , describe "when the subscription is a mapped Sub"
      [ test "the data is tagged and processed" <|
        \() ->
          let
            initialState = Elmer.given App.defaultModel App.view App.update
            override =
              Spy.observe (\_ -> Time.every)
                |> Spy.andCallFake (\interval tagger ->
                  Subscription.fake ("fakeTime-" ++ (String.fromFloat interval)) tagger
                )
          in
            Spy.use [ override ] initialState
              |> Subscription.with (\() -> App.mappedSubscriptions)
              |> Subscription.send "fakeTime-3600000" (Time.millisToPosix (1000 * 60 * 60 * 18))
              |> Markup.target << by [ id "child-hours" ]
              |> Markup.expect ( element <| hasText "18 hours" )
      ]
    ]
  ]
