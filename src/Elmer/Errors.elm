module Elmer.Errors exposing
  ( CustomError
  , failWith
  , print
  , noModel
  , noTitle
  , wrongTitle
  , noLocation
  , wrongLocation
  , sendUrlRequiresApplication
  , badUrl
  , navigationSpyRequiresApplication
  , elementNotFound
  , wrongProperty
  , noProperty
  )

{-| Exposed for testing

@docs CustomError, print, failWith
@docs noModel, noTitle, wrongTitle, noLocation, wrongLocation, sendUrlRequiresApplication
@docs badUrl, navigationSpyRequiresApplication, elementNotFound, wrongProperty, noProperty

-}

import Expect exposing (Expectation)
import Elmer.Printer exposing (..)

{-|
-}
type alias CustomError
  = List Message

{-|
-}
noModel : CustomError
noModel =
  [ description "No model! Call Elmer.init to provide a model."
  ]


{-|
-}
wrongTitle : String -> String -> CustomError
wrongTitle expected actual =
  [ message "Expected document to have title" expected
  , message "but it has" actual
  ]


{-|
-}
noTitle : String -> CustomError
noTitle expected =
  [ message "Expected document to have title" expected
  , description "but the supplied view function does not result in a Document value"
  ]


{-|
-}
noLocation : String -> CustomError
noLocation expected =
  [ message "Expected to be at location:" expected
  , description "but no location has been set"
  ]


{-|
-}
wrongLocation : String -> String -> CustomError
wrongLocation expected actual =
  [ message "Expected to be at location:" expected
  , message "but location is:" actual
  ]


{-|
-}
sendUrlRequiresApplication : CustomError
sendUrlRequiresApplication =
  [ description "sendUrlRequest can only be used when testing an Elm Html application."
  , description "Use Elmer.Application.given to initialize this test."
  ]


{-|
-}
badUrl : String -> String -> CustomError
badUrl fun expected =
  [ message ("Fake " ++ fun ++ " could not process url") expected
  , description "because it does not appear to be a url"
  ]


{-|
-}
navigationSpyRequiresApplication : String -> String -> CustomError
navigationSpyRequiresApplication fun expected =
  [ message ("Fake " ++ fun ++ " could not process url") expected
  , description "Use Elmer.Application.given to initialize this test."
  ]


{-|
-}
elementNotFound : String -> String -> CustomError
elementNotFound selector dom =
  [ message "No html element found with selector" selector
  , message "The current view is" dom
  ]


{-|
-}
wrongProperty : String -> String -> String -> CustomError
wrongProperty property expectedValue actualValue =
  [ message "Expected element to have property" <| property ++ " = " ++ expectedValue
  , message "but it has" <| property ++ " = " ++ actualValue
  ]


{-|
-}
noProperty : String -> String -> CustomError
noProperty property expectedValue =
  [ message "Expected element to have property" <| property ++ " = " ++ expectedValue
  , description "but it has no property with that name"
  ]

{-|
-}
failWith : CustomError -> Expectation
failWith =
  Expect.fail << print

{-|
-}
print : CustomError -> String
print =
  format