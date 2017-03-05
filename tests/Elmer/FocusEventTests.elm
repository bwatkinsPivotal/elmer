module Elmer.FocusEventTests exposing (all)

import Test exposing (..)
import Elmer.TestApps.FocusTestApp as App
import Expect
import Elmer
import Elmer.EventTests as EventTests
import Elmer.Internal exposing (..)
import Elmer.Html.Event as Event
import Elmer.Platform.Command as Command
import Elmer.Html as Markup

all : Test
all =
  describe "Focus Event Tests"
    [ focusTests
    , blurTests
    ]

focusTests : Test
focusTests =
  describe "focus"
  [ EventTests.standardEventBehavior Event.focus "focus"
  , EventTests.propagationBehavior Event.focus "focus"
  , let
      initialModel = App.defaultModel
      initialState = Elmer.componentState initialModel App.view App.update
    in
      describe "the focus event"
      [ test "at first the element is not focused" <|
        \() ->
          Expect.equal initialModel.isFocused False
      , test "the event updates the model" <|
        \() ->
          let
            updatedStateResult = Markup.find "#name-field" initialState
                                  |> Event.focus
          in
            case updatedStateResult of
              Ready updatedState ->
                Expect.equal updatedState.model.isFocused True
              Failed msg ->
                Expect.fail msg
      ]
  ]

blurTests : Test
blurTests =
  describe "blur"
  [ EventTests.standardEventBehavior Event.blur "blur"
  , EventTests.propagationBehavior Event.blur "blur"
  , let
      initialModel = App.defaultModel
      initialState = Elmer.componentState initialModel App.view App.update
    in
      describe "the blur event"
      [ test "at first the element is not blurred" <|
        \() ->
          Expect.equal initialModel.isBlurred False
      , test "the event updates the model" <|
        \() ->
          let
            updatedStateResult = Markup.find "#name-field" initialState
                                  |> Event.blur
          in
            case updatedStateResult of
              Ready updatedState ->
                Expect.equal updatedState.model.isBlurred True
              Failed msg ->
                Expect.fail msg
      ]
  ]
