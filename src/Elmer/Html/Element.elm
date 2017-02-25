module Elmer.Html.Element exposing
  ( id
  , classList
  , property
  , properties
  , attributes
  , toString
  )

{-| Functions for working directly with HtmlElements.

# Element Characteristics
@docs id, classList, property, properties, attributes

# Debugging
@docs toString

-}

import Elmer.Html
import Elmer.Html.Internal as Internal
import Dict exposing (Dict)

{-| Represent an `HtmlElement` as a String.
-}
toString : Elmer.Html.HtmlElement msg -> String
toString node =
  Internal.toString node

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

{-| Get the value of a particular property belonging to this
element, if that property is defined.
-}
property : String -> Elmer.Html.HtmlElement msg -> Maybe String
property name =
  Internal.property name

{-| Get this element's properties as a `Dict`.

On the difference between attributes and properties,
see [this](https://github.com/elm-lang/html/blob/master/properties-vs-attributes.md).
-}
properties : Elmer.Html.HtmlElement msg -> Dict String String
properties =
  Internal.properties

{-| Get this element's attributes as a `Dict`. If you define a custom attribute
for an Html element, you can find it with this function.

    componentState
      |> expectElement (\element ->
        attributes element
          |> Dict.get "data-attribute"
          |> Expect.notEqual Nothing
      )
-}
attributes : Elmer.Html.HtmlElement msg -> Dict String String
attributes =
  Internal.attributes