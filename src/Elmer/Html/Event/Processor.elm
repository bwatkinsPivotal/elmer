module Elmer.Html.Event.Processor exposing
  ( processEvents
  , processEventsWhen
  )

import Elmer.Html.Event.Types exposing (..)
import Elmer.Html.Types exposing (..)
import Elmer.Html.Selector.Printer as Selector
import Elmer.TestState as TestState exposing (TestState)
import Elmer.Context as Context exposing (Context)
import Elmer.Runtime as Runtime
import Elmer.Errors as Errors
import Json.Decode as Json
import Elmer.Html.Query as Query
import Elmer.Html.Target as Target
import Html exposing (Html)


processEventsWhen : List (EventDescription msg) -> (Result String (HtmlElement msg) -> Result String (HtmlElement msg)) -> TestState model msg -> TestState model msg
processEventsWhen eventDescriptions assertions =
  TestState.map (\context ->
    targetedElement context
      |> assertions
      |> Result.andThen (hasHandlersFor eventDescriptions context)
      |> Result.andThen (apply eventDescriptions context)
      |> toTestState
  )


processEvents : List (EventDescription msg) -> TestState model msg -> TestState model msg
processEvents eventDescriptions =
  processEventsWhen eventDescriptions identity


hasHandlersFor : List (EventDescription msg) -> Context model msg -> HtmlElement msg -> Result String (HtmlElement msg)
hasHandlersFor eventDescriptions context element =
  let
    handlers = List.map (\ed -> ed.handlers (renderViewWithDefault context) element) eventDescriptions
      |> List.concat
  in
    if List.isEmpty handlers then
      let
        eventTypes =
          List.map .eventType eventDescriptions
            |> String.join ", "
        selector =
          targetedSelector context
            |> Maybe.map Selector.printGroup
            |> Maybe.withDefault "<No element has been targeted>"
      in
        Err <| 
          Errors.print <| Errors.eventHandlerNotFound eventTypes selector
    else
      Ok element


apply : List (EventDescription msg) -> Context model msg -> HtmlElement msg -> Result String (Context model msg)
apply eventDescriptionList context element =
  List.foldl (\evtDescr result ->
    Result.andThen (\ctxt ->
      collectEventHandlers evtDescr.handlers ctxt element
        |> bubbleEvent evtDescr.eventJson (Ok ctxt)
    ) result
  ) (Ok context) eventDescriptionList


targetedSelector : Context model msg -> Maybe (HtmlSelectorGroup msg)
targetedSelector =
  Context.state TargetSelector


targetedElement : Context model msg -> Result String (HtmlElement msg)
targetedElement context =
  case targetedSelector context of
    Just selector ->
      case Context.render context of
        Just view ->
          Query.findElement <| Target.forHtml selector view
        Nothing ->
          Err <| Errors.print Errors.noModel
    Nothing ->
      Err <| Errors.print <| Errors.noElementTargetedForEvent


prepareHandler : HtmlEventHandler msg -> EventHandler msg
prepareHandler eventHandler eventJson =
  Json.decodeString eventHandler.decoder eventJson
    |> Result.mapError Debug.toString


collectEventHandlers : EventHandlerQuery msg -> Context model msg -> HtmlElement msg -> List (EventHandler msg)
collectEventHandlers eventHandlerQuery context element =
  eventHandlerQuery (renderViewWithDefault context) element
    |> List.map prepareHandler


bubbleEvent : EventJson -> Result String (Context model msg) -> List (EventHandler msg) -> Result String (Context model msg)
bubbleEvent event contextResult eventHandlers =
  case eventHandlers of
    [] ->
      contextResult
    eventHandler :: remaining ->
      case eventHandler event of
        Ok eventValue ->
          let
            result = 
              Result.andThen (Runtime.performUpdate eventValue.message) contextResult 
          in
            if eventValue.stopPropagation == True then
              result
            else
              bubbleEvent event result remaining
        Err error ->
          Err error


toTestState : Result String (Context model msg) -> TestState model msg
toTestState contextResult =
  case contextResult of
    Ok context ->
      TestState.with context
    Err message ->
      TestState.failure message


renderViewWithDefault : Context model msg -> Html msg
renderViewWithDefault context =
  Context.render context
    |> Maybe.withDefault (Html.text "")


takeUpTo : (a -> Bool) -> List a -> List a
takeUpTo predicate elements =
  case elements of
    [] ->
      []
    x :: xs ->
      if not <| predicate x then
        x :: takeUpTo predicate xs
      else
        [ x ]
