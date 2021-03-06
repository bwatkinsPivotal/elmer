module Elmer.Html.Element exposing
  ( id
  , tag
  , target
  , classList
  , property
  , boolProperty
  , properties
  , attributes
  , styles
  , texts
  , children
  , toString
  )

{-| Functions for working directly with HtmlElements.

# Element Characteristics
@docs tag, id, classList, styles, property, boolProperty, properties, attributes, texts, children

# Target Descendants
@docs target

# Debugging
@docs toString

-}


import Elmer.Html
import Elmer.Html.Element.Internal as Internal
import Elmer.Html.Target as Target
import Elmer.Html.Element.Printer as HtmlPrinter
import Elmer.Html.Selector as Selector
import Elmer.Html.Types exposing (HtmlSelectorGroup(..))
import Dict exposing (Dict)


{-| Target descendants of an element.

Use this function in conjunction with `HtmlTarget` matchers like `element` or `elements`
to make expectations about descendants of an element.

    Elmer.given someModel view update
      |> Elmer.Html.target
          << by [ id "some-element" ]
      |> Elmer.Html.expect (Elmer.Html.Matchers.element <|
          \element ->
            element
              |> target << by [ tag "div" ]
              |> Elmer.Html.Matchers.elements (
                Elmer.hasLength 3
              )
        )

Note that `Elmer.Html.target << descendantsOf [ id "some-element" ] << by [ tag "div" ]` would allow you to write the
same expectation. Use `Element.target` for complex expectations about nested elements.

-}
target : (HtmlSelectorGroup msg, Elmer.Html.HtmlElement msg) -> Elmer.Html.HtmlTarget msg
target (selectors, element) =
  Target.forElement selectors element


{-| Represent an `HtmlElement` as a String.
-}
toString : Elmer.Html.HtmlElement msg -> String
toString node =
  HtmlPrinter.print node


{-| Get the tag of the element
-}
tag : Elmer.Html.HtmlElement msg -> String
tag =
  Internal.tag


{-| Get the value of the element's `id` attribute, if it is defined.
-}
id : Elmer.Html.HtmlElement msg -> Maybe String
id =
  Internal.elementId


{-| Get a list of classes applied to this element.
-}
classList : Elmer.Html.HtmlElement msg -> List String
classList =
  Internal.classList


{-| Get the `Html.text` values that are children of this element.
-}
texts : Elmer.Html.HtmlElement msg -> List String
texts =
  Internal.texts


{-| Get the Html elements that are children of this element.

Note that `Html.text` values are excluded. Use `texts` to get those.
-}
children : Elmer.Html.HtmlElement msg -> List (Elmer.Html.HtmlElement msg)
children =
  Internal.childElements


{-| Get this element's styles as a `Dict`.
-}
styles : Elmer.Html.HtmlElement msg -> Dict String String
styles =
  Internal.styles


{-| Get the value of a particular property belonging to this
element, if that property is defined.
-}
property : String -> Elmer.Html.HtmlElement msg -> Maybe String
property name =
  Internal.property name


{-| Get the boolean value of a particular property belonging to
this element, if that property is defined.

If the property is defined, but its value is not boolean, then
`Nothing` is returned.
-}
boolProperty : String -> Elmer.Html.HtmlElement msg -> Maybe Bool
boolProperty name element =
  property name element
    |> Maybe.andThen toBool


toBool : String -> Maybe Bool
toBool str =
  case str of
    "true" ->
      Just True
    "false" ->
      Just False
    _ ->
      Nothing


{-| Get this element's properties as a `Dict`.

On the difference between attributes and properties,
see [this](https://github.com/elm/html/blob/master/properties-vs-attributes.md).
-}
properties : Elmer.Html.HtmlElement msg -> Dict String String
properties =
  Internal.properties


{-| Get this element's attributes as a `Dict`. If you define a custom attribute
for an Html element, you can find it with this function.

    Elmer.given someModel view update
      |> target << by [ id "some-element" ]
      |> expect (element <| \element ->
        attributes element
          |> Dict.get "data-attribute"
          |> Expect.notEqual Nothing
      )
-}
attributes : Elmer.Html.HtmlElement msg -> Dict String String
attributes =
  Internal.attributes
