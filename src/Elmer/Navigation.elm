module Elmer.Navigation exposing
  ( setLocation
  , expectLocation
  )

import Navigation
import Elmer.Event as Event
import Elmer exposing (..)
import Expect

expectLocation : String -> ComponentStateResult navData model msg -> Expect.Expectation
expectLocation expectedURL componentStateResult =
  case componentStateResult of
    CurrentState componentState ->
      case componentState.location of
        Just location ->
          Expect.equal location expectedURL
            |> Expect.onFail ("Expected to be at location:\n\n\t" ++ expectedURL ++ "\n\nbut location is:\n\n\t" ++ location)
        Nothing ->
          Expect.fail ("Expected to be at location:\n\n\t" ++ expectedURL ++ "\n\nbut no location has been set")
    UpstreamFailure msg ->
      Expect.fail msg

setLocation : String -> ComponentStateResult navData model msg -> ComponentStateResult navData model msg
setLocation location componentStateResult =
  componentStateResult
    |> map ( \componentState ->
        case componentState.locationParser of
          Just locationParser ->
            case componentState.urlUpdate of
              Just urlUpdate ->
                let
                  command = Navigation.newUrl location
                in
                  Event.sendCommand command componentStateResult
              Nothing ->
                UpstreamFailure "setLocation failed because no urlUpdate was set"
          Nothing ->
            UpstreamFailure "setLocation failed because no locationParser was set"
      )
