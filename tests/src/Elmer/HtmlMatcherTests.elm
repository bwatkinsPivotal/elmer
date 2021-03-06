module Elmer.HtmlMatcherTests exposing (..)

import Test exposing (..)
import Elmer.TestHelpers exposing (..)
import Elmer.TestApps.SimpleTestApp as SimpleApp
import Expect exposing (Expectation)
import Elmer exposing (..)
import Elmer.Html as Markup
import Elmer.Html.Matchers as Matchers
import Elmer.Html.Selector as Sel exposing (..)
import Elmer.Html.Node as Node
import Elmer.Html.Types exposing (..)
import Elmer.Html.Element.Printer as HtmlPrinter
import Elmer.Message exposing (..)
import Elmer.Errors as Errors exposing (CustomError)
import Elmer.TestHelpers exposing (printHtml, expectError)
import Html exposing (Html, Attribute)
import Html.Attributes as Attr
import Dict


all : Test
all =
  Test.concat
  [ elementTests
  , elementsTests
  , elementExistsTests
  , hasTextTests
  , hasClassTests
  , hasPropertyTests
  , hasAttributeTests
  , hasIdTests
  , hasStyleTests
  , listensForEventTests
  ]


simpleState : TestState SimpleApp.Model SimpleApp.Msg
simpleState =
  Elmer.given SimpleApp.defaultModel SimpleApp.view (\_ model -> (model, Cmd.none))

testTextHtmlState : TestState SimpleApp.Model SimpleApp.Msg
testTextHtmlState =
  Elmer.given SimpleApp.defaultModel SimpleApp.textView (\_ model -> (model, Cmd.none))

testChildrenHtmlState : TestState SimpleApp.Model SimpleApp.Msg
testChildrenHtmlState =
  Elmer.given SimpleApp.defaultModel SimpleApp.viewWithChildren (\_ model -> (model, Cmd.none))


elementTests : Test
elementTests =
  describe "element"
  [ describe "when the targeted element does not exist"
    [ test "it returns the failure message and prints the view" <|
      \() ->
        simpleState
          |> Markup.target << by [ class "blah" ]
          |> Markup.expect (Matchers.element <| Matchers.hasClass "blah" )
          |> expectError (
            Errors.elementNotFound "by [ class 'blah' ]" <| 
              printHtml <| SimpleApp.view SimpleApp.defaultModel
          )
    ]
  , describe "when there are no elements in the html"
    [ test "it shows there are no elements found" <|
      \() ->
        testTextHtmlState
          |> Markup.target << by [ class "blah" ]
          |> Markup.expect (Matchers.element <| Matchers.hasClass "blah")
          |> expectError (
            Errors.elementNotFound "by [ class 'blah' ]" <|
              printHtml <| SimpleApp.textView SimpleApp.defaultModel
          )
    ]
  , describe "when the targeted element exists"
    [ test "it passes the element to the matcher" <|
      \() ->
        simpleState
          |> Markup.target << by [ id "root" ]
          |> Markup.expect (Matchers.element <| Matchers.hasText "Some text")
          |> Expect.equal Expect.pass
    ]
  ]

elementsTests : Test
elementsTests =
  describe "elements"
  [ describe "when the targeted element does not exist"
    [ test "it passes an empty list to the matcher" <|
      \() ->
        testChildrenHtmlState
          |> Markup.target << by [ tag "blah" ]
          |> Markup.expect (Matchers.elements <| \els ->
            Expect.equal True <| List.isEmpty els
          )
    ]
  , describe "when the targeted element exists"
    [ test "it passes the matching elements to the matcher" <|
      \() ->
        testChildrenHtmlState
          |> Markup.target << by [ tag "div" ]
          |> Markup.expect (Matchers.elements <| \els ->
            Expect.equal 4 <| List.length els
          )
    ]
  ]

elementExistsTests : Test
elementExistsTests =
  describe "elementExists"
  [ describe "when the targeted element does not exist"
    [ test "it fails" <|
      \() ->
        simpleState
          |> Markup.target << by [ class "blah" ]
          |> Markup.expect Matchers.elementExists
          |> expectError (
            Errors.elementNotFound "by [ class 'blah' ]" <|
              printHtml <| SimpleApp.view SimpleApp.defaultModel
          )
    ]
  , describe "when the targeted element exists"
    [ test "it passes" <|
      \() ->
        simpleState
          |> Markup.target << by [ id "root" ]
          |> Markup.expect Matchers.elementExists
          |> Expect.equal Expect.pass
    ]
  ]


hasTextTests : Test
hasTextTests =
  describe "hasText"
  [ describe "when the element has no text"
    [ test "it fails with the right message" <|
      \() ->
        Matchers.hasText "Some text" (emptyNode "div")
          |> Expect.equal (Expect.fail "Expected element to have text\n\n\tSome text\n\nbut it has no text")
    ]
  , describe "when the element has the wrong text"
    [ test "it fails with the right message" <|
      \() ->
        Matchers.hasText "Some text" (nodeWithText "other text")
          |> Expect.equal (Expect.fail "Expected element to have text\n\n\tSome text\n\nbut it has\n\n\tother text")
    ]
  , describe "when the element has the text"
    [ test "it passes" <|
      \() ->
        Matchers.hasText "Some text" (nodeWithText "Some text")
          |> Expect.equal Expect.pass
    ]
  , describe "when the element has multiple text nodes, one of which has the text"
    [ test "it passes" <|
      \() ->
        Matchers.hasText "Some text" (nodeWithMultipleChildren "Some text")
          |> Expect.equal Expect.pass
    ]
    , describe "when the element has multiple text nodes, none of which has the text"
      [ test "it fails with the right message" <|
        \() ->
          Matchers.hasText "Other stuff" (nodeWithMultipleChildren "Some text")
            |> Expect.equal (Expect.fail "Expected element to have text\n\n\tOther stuff\n\nbut it has\n\n\tfun stuff, Some text")
      ]
    , describe "when the text is in a child node"
      [ test "it finds the text" <|
        \() ->
          Matchers.hasText "Child Text" (nodeWithNestedChildren "Child Text")
            |> Expect.equal Expect.pass
      ]
  ]

hasClassTests : Test
hasClassTests =
  describe "hasClass"
  [ describe "when the element has no classes"
    [ test "it fails with the right message" <|
      \() ->
        Matchers.hasClass "myClass" (emptyNode "div")
          |> Expect.equal (Expect.fail "Expected element to have class\n\n\tmyClass\n\nbut it has no classes")
    ]
  , describe "when the element has classes"
    [ describe "when the element does not have the specified class"
      [ test "it fails with the right message" <|
        \() ->
          Matchers.hasClass "myClass" (nodeWithClass "anotherClass")
            |> Expect.equal (Expect.fail "Expected element to have class\n\n\tmyClass\n\nbut it has\n\n\tanotherClass, funClass")
      ]
    , describe "when the element has the specified class"
      [ test "it passes" <|
        \() ->
          Matchers.hasClass "myClass" (nodeWithClass "myClass")
            |> Expect.equal Expect.pass
      ]
    ]
  ]


hasPropertyTests : Test
hasPropertyTests =
  describe "hasProperty"
  [ describe "when the node has no properties"
    [ test "it fails with the right message" <|
      \() ->
        Matchers.hasAttribute ("some-property", "some <i>html</i>") (emptyNode "div")
          |> expectError (Errors.noAttribute "some-property" "some <i>html</i>")
    ]
  , describe "when the node has properties"
    [ describe "when the node does not have the specified property"
      [ test "it fails with the right message" <|
        \() ->
          Matchers.hasAttribute ("some-property", "some <i>html</i>") (nodeWithProperty ("someProperty", "blah"))
            |> expectError (Errors.wrongAttributeName "some-property" "some <i>html</i>" <| Dict.fromList [("someProperty", "blah")])
      ]
    , describe "when the node has the specified property"
      [ describe "when the value is incorrect"
        [ test "it fails" <|
          \() ->
            Matchers.hasAttribute ("some-property", "some <i>html</i>") (nodeWithProperty ("some-property", "blah"))
              |> expectError (Errors.wrongAttribute "some-property" "some <i>html</i>" "blah")
        ]
      , describe "when the value is correct"
        [ test "it passes" <|
          \() ->
            Matchers.hasAttribute ("some-property", "some <i>html</i>") (nodeWithProperty ("some-property", "some <i>html</i>"))
              |> Expect.equal Expect.pass
        ]
      ]
    ]
  ]

elementWithAttributes : List (String, String) -> HtmlElement msg
elementWithAttributes attributes =
  let
    attrs = List.map (\(name, value) -> Attr.attribute name value) attributes
    html = Html.div attrs []
  in
    Node.from html
      |> Node.asElement
      |> Maybe.withDefault (nodeWithId "fail")


hasAttributeTests : Test
hasAttributeTests =
  describe "hasAttribute"
  [ describe "when the node has no attributes"
    [ test "it fails with the right message" <|
      \() ->
        Matchers.hasAttribute ("data-fun-attribute", "something") (emptyNode "div")
          |> expectError (Errors.noAttribute "data-fun-attribute" "something")
    ]
  , describe "when the element has attributes"
    [ describe "when the node does not have the specified attribute"
      [ test "it fails with the right message" <|
        \() ->
          Matchers.hasAttribute ("data-fun-attribute", "something") (elementWithAttributes [("someProperty", "blah")])
            |> expectError (Errors.wrongAttributeName "data-fun-attribute" "something" <| Dict.fromList [("someProperty", "blah")])
      ]
    , describe "when the element has the specified attribute"
      [ describe "when the value is incorrect"
        [ test "it fails" <|
          \() ->
            Matchers.hasAttribute ("data-fun-attribute", "something") (elementWithAttributes [("data-fun-attribute", "blah")])
              |> expectError (Errors.wrongAttribute "data-fun-attribute" "something" "blah")
        ]
      , describe "when the value is correct"
        [ test "it passes" <|
          \() ->
            Matchers.hasAttribute ("data-fun-attribute", "something") (elementWithAttributes [("data-fun-attribute", "something")])
              |> Expect.equal Expect.pass
        ]
      ]
    ]
  ]

hasIdTests : Test
hasIdTests =
  describe "hasId"
  [ describe "when the node has no id"
    [ test "it fails with the right message" <|
      \() ->
        Matchers.hasId "root" (emptyNode "div")
          |> Expect.equal (Expect.fail "Expected element to have id\n\n\troot\n\nbut it has no id")
    ]
  , describe "when the node has an id"
    [ describe "when the id does not match"
      [ test "it fails" <|
        \() ->
          Matchers.hasId "root" (nodeWithId "blah")
            |> Expect.equal (Expect.fail "Expected element to have id\n\n\troot\n\nbut it has id\n\n\tblah")
      ]
    , describe "when the id matches"
      [ test "it passes" <|
        \() ->
          Matchers.hasId "root" (nodeWithId "root")
            |> Expect.equal (Expect.pass)
      ]
    ]
  ]

hasStyleTests : Test
hasStyleTests =
  describe "hasStyle"
  [ describe "when the element has no style"
    [ test "it fails" <|
      \() ->
        Matchers.hasStyle ("position", "relative") (emptyNode "div")
          |> Expect.equal (Expect.fail <|
            format
              [ fact "Expected element to have style" "position: relative"
              , note "but it has no style"
              ]
            )
    ]
  , describe "when the element has some other style"
    [ test "it fails" <|
      \() ->
        Matchers.hasStyle ("position", "relative") (elementWithStyles [ ("left", "0px"), ("top", "20px") ])
          |> Expect.equal (Expect.fail <|
            format
              [ fact "Expected element to have style" "position: relative"
              , fact "but it has style" "left: 0px\ntop: 20px"
              ]
            )
    ]
  , describe "when the element has the style name but not the style value"
    [ test "it fails" <|
      \() ->
        Matchers.hasStyle ("position", "relative") (elementWithStyles [("position", "absolute")])
          |> Expect.equal (Expect.fail <|
            format
              [ fact "Expected element to have style" "position: relative"
              , fact "but it has style" "position: absolute"
              ]
            )

    ]
  , describe "when the element has the style"
    [ test "it passes" <|
      \() ->
        Matchers.hasStyle ("position", "relative") (elementWithStyles [("margin", "10px"), ("position", "relative")])
          |> Expect.equal Expect.pass
    ]
  ]

elementWithStyles : List (String, String) -> HtmlElement msg
elementWithStyles styles =
  let
    html = Html.div (styleAttributes styles) []
  in
    Node.from html
      |> Node.asElement
      |> Maybe.withDefault (nodeWithId "fail")

styleAttributes : List (String, String) -> List (Attribute msg)
styleAttributes =
  List.map (\style -> Attr.style (Tuple.first style) (Tuple.second style))

listensForEventTests : Test
listensForEventTests =
  describe "listensForEvent"
  [ describe "when the element has no event listeners"
    [ test "it fails" <|
      \() ->
        Matchers.listensForEvent "click" (emptyNode "div")
          |> Expect.equal (Expect.fail <|
            format
              [ fact "Expected element to listen for event" "click"
              , note "but it has no event listeners"
              ]
            )
    ]
  , describe "when the element does not have the correct event listener"
    [ test "it fails" <|
      \() ->
        Matchers.listensForEvent "click" (nodeWithEvents [ "mouseup", "mousedown" ])
          |> Expect.equal (Expect.fail <|
            format
              [ fact "Expected element to listen for event" "click"
              , fact "but it listens for" "mouseup\nmousedown"
              ]
            )
    ]
  , describe "when the element has the expected event listener"
    [ test "it passes" <|
      \() ->
        Matchers.listensForEvent "click" (nodeWithEvents [ "mouseup", "click", "mousedown" ])
          |> Expect.equal Expect.pass
    ]
  ]
