module Elmer.ComponentTests exposing (all)

import Test exposing (..)
import Expect

import Elmer exposing (..)
import Elmer.Event as Event
import Elmer.Matchers as Matchers

import Elmer.TestApps.ComponentTestApp as App exposing (..)

all =
  describe "Component tests"
  [ mapCommand
  ]


mapCommand =
  describe "Map Command"
  [ describe "within a single component"
    [ test "it handles a map command" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultModel App.view App.update
          mapCommand = Cmd.map DoFun subTask
        in
          Event.sendCommand mapCommand initialState
            |> Elmer.find "#root"
            |> Elmer.expectNode (Matchers.hasText "Fun: bowling")
    , test "it handles a click event" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultModel App.view App.update
          mapCommand = Cmd.map DoFun subTask
        in
          Event.sendCommand mapCommand initialState
            |> Elmer.find "#click-display"
            |> Event.click
            |> Elmer.find "#root"
            |> Elmer.expectNode (Matchers.hasText "Fun: click")
    ]
  , describe "when a child component is used by the parent"
    [ test "it handles a mapped map command" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultParentModel App.parentView App.parentUpdate
          mapCommand = Cmd.map DoFun subTask
          parentMapCommand = Cmd.map MsgAWrapper mapCommand
        in
          Event.sendCommand parentMapCommand initialState
            |> Elmer.find "#child-view"
            |> Elmer.expectNode (Matchers.hasText "Fun: bowling")
    , test "it handles a mapped message from the child view" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultParentModel App.parentView App.parentUpdate
          mapCommand = Cmd.map DoFun subTask
          parentMapCommand = Cmd.map MsgAWrapper mapCommand
        in
          Event.sendCommand parentMapCommand initialState
            |> Elmer.find "#click-display"
            |> Event.click
            |> Elmer.find "#child-view"
            |> Elmer.expectNode (Matchers.hasText "Fun: click")
    , describe "when the mapped command has a custom update method"
      [ test "it handles a mapped message from the child view" <|
        \() ->
          let
            initialState = navigationComponentState App.defaultParentModel App.parentView App.parentUpdate App.parseLocation
          in
            Elmer.find "#change-location" initialState
              |> Event.click
              |> Elmer.find "#fun-stuff"
              |> Elmer.expectNode (Matchers.hasText "Fun things!")
      ]
    ]
  ]