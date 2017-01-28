module Elmer.Http exposing
  ( HttpResponseStub
  , HttpResponseResult(..)
  , HttpRequestFunction
  , HttpRequest
  , asHttpRequest
  , fakeHttpSend
  , expectPOST
  , expectGET
  , expectDELETE
  , clearRequestHistory
  )

import Http
import Dict
import Elmer
import Elmer.Types exposing (..)
import Elmer.Command as Command
import Elmer.Command.Internal as InternalCommand
import Elmer.Printer exposing (..)
import Expect exposing (Expectation)


type alias HttpRequestFunction a b =
  (Result Http.Error a -> b) -> Http.Request a -> Cmd b

type alias HttpRequest a =
  { method: String
  , url: String
  , headers: List HttpHeader
  , body: Maybe String
  , responseHandler: (Http.Response String -> Result String a)
  }

type alias HttpResponseStub =
  { url: String
  , method: String
  , response: HttpResponseResult
  , deferResponse: Bool
  }

type HttpResponseResult
  = HttpResponse (Http.Response String)
  | HttpError Http.Error


asHttpRequest : Http.Request a -> HttpRequest a
asHttpRequest request =
  Native.Helpers.asHttpRequest request

fakeHttpSend : HttpResponseStub -> HttpRequestFunction a msg
fakeHttpSend responseStub tagger request =
  let
    httpRequest = asHttpRequest request
  in
    responseStubIsValid responseStub
      |> Result.andThen (matchRequest httpRequest)
      |> Result.andThen generateResponse
      |> Result.andThen (processResponse httpRequest tagger)
      |> collapseToCommand
      |> toHttpCommand responseStub.deferResponse httpRequest

collapseToCommand : Result (Cmd msg) (Cmd msg) -> Cmd msg
collapseToCommand responseResult =
  case responseResult of
    Ok command ->
      command
    Err errorCommand ->
      errorCommand


toHttpCommand : Bool -> HttpRequest a -> Cmd msg -> Cmd msg
toHttpCommand shouldDeferResponse request command =
  let
    requestData =
      { method = request.method
      , url = request.url
      , body = request.body
      , headers = request.headers
      }
    httpCommand = InternalCommand.mapState <| updateComponentState requestData
  in
    if shouldDeferResponse then
      Cmd.batch [ httpCommand, Command.defer command ]
    else
      Cmd.batch [ httpCommand, command ]

updateComponentState : HttpRequestData -> HtmlComponentState model msg -> HtmlComponentState model msg
updateComponentState requestData componentState =
  { componentState | httpRequests = requestData :: componentState.httpRequests }

clearRequestHistory : ComponentStateResult model msg -> ComponentStateResult model msg
clearRequestHistory =
  Elmer.map (\componentState ->
    if List.isEmpty componentState.httpRequests then
      UpstreamFailure "No HTTP requests to clear"
    else
      CurrentState { componentState | httpRequests = [] }
  )

expectPOST : String -> (HttpRequestData -> Expect.Expectation) -> ComponentStateResult model msg -> Expect.Expectation
expectPOST =
  expectRequest "POST"

expectGET : String -> (HttpRequestData -> Expect.Expectation) -> ComponentStateResult model msg -> Expect.Expectation
expectGET =
  expectRequest "GET"

expectDELETE : String -> (HttpRequestData -> Expect.Expectation) -> ComponentStateResult model msg -> Expect.Expectation
expectDELETE =
  expectRequest "DELETE"

expectRequest : String -> String -> (HttpRequestData -> Expect.Expectation) -> ComponentStateResult model msg -> Expect.Expectation
expectRequest method url requestMatcher =
  Elmer.mapToExpectation <|
    \componentState ->
      if String.contains "?" url then
        Expect.fail ( format
          [ message "The expected route contains a query string" url
          , description "Use the hasQueryParam matcher instead"
          ]
        )
      else
        case hasRequest componentState.httpRequests method url of
          Just request ->
            requestMatcher request
          Nothing ->
            if List.isEmpty componentState.httpRequests then
              Expect.fail (format [ message "Expected request for" (method ++ " " ++ url), description "but no requests have been made" ])
            else
              let
                requests = String.join "\n\n\t" (List.map (\r -> r.method ++ " " ++ r.url) componentState.httpRequests)
              in
              Expect.fail (format [ message "Expected request for" (method ++ " " ++ url), message "but only found these requests" requests ])

hasRequest : List HttpRequestData -> String -> String -> Maybe HttpRequestData
hasRequest requests method url =
  List.filter (\r -> r.method == method && (route r.url) == url) requests
    |> List.head

responseStubIsValid : HttpResponseStub -> Result (Cmd msg) HttpResponseStub
responseStubIsValid responseStub =
  if String.contains "?" responseStub.url then
    Err (Command.failureCommand (format [message "Sent a request where a stubbed route contains a query string" responseStub.url, description "Stubbed routes may not contain a query string"]))
  else
    Ok responseStub

matchRequest : HttpRequest a -> HttpResponseStub -> Result (Cmd msg) HttpResponseStub
matchRequest httpRequest responseStub =
  matchRequestUrl httpRequest responseStub
    |> Result.andThen (matchRequestMethod httpRequest)

matchRequestUrl : HttpRequest a -> HttpResponseStub -> Result (Cmd msg) HttpResponseStub
matchRequestUrl httpRequest responseStub =
  if (route httpRequest.url) == responseStub.url then
    Ok responseStub
  else
    Err (Command.failureCommand (format [message "Received a request for" httpRequest.url, message "but it has not been stubbed. The stubbed request is" responseStub.url ]))

route : String -> String
route url =
  String.split "?" url
    |> List.head
    |> Maybe.withDefault ""

matchRequestMethod : HttpRequest a -> HttpResponseStub -> Result (Cmd msg) HttpResponseStub
matchRequestMethod httpRequest responseStub =
  if httpRequest.method == responseStub.method then
    Ok responseStub
  else
    Err (Command.failureCommand (format [message "A response has been stubbed for" httpRequest.url, description ("but it expects a " ++ responseStub.method ++ " not a " ++ httpRequest.method) ]))


generateResponse : HttpResponseStub -> Result (Cmd msg) (HttpResponseResult)
generateResponse responseStub =
  Ok responseStub.response


processResponse : HttpRequest a -> (Result Http.Error a -> msg) -> HttpResponseResult -> Result (Cmd msg) (Cmd msg)
processResponse httpRequest tagger responseResult =
  handleResponseError responseResult
    |> Result.andThen handleResponseStatus
    |> Result.andThen (handleResponse httpRequest)
    |> Result.mapError (mapResponseError httpRequest tagger)
    |> Result.map (\d -> Command.stub (tagger (Ok d)))

mapResponseError : HttpRequest a -> (Result Http.Error a -> msg) -> Http.Error -> Cmd msg
mapResponseError httpRequest tagger error =
  case error of
    Http.BadPayload msg response ->
      Command.failureCommand (format
        [ message "Parsing a stubbed response" (httpRequest.method ++ " " ++ httpRequest.url)
        , description ("\t" ++ response.body)
        , message "failed with error" msg
        , description "If you really want to generate a BadPayload error, consider using\nElmer.Http.Stub.withError to build your stubbed response."
        ]
      )
    _ ->
      Command.stub (tagger (Err error))


handleResponseError : HttpResponseResult -> Result Http.Error (Http.Response String)
handleResponseError responseResult =
  case responseResult of
    HttpResponse response ->
      Ok response
    HttpError error ->
      Err error


handleResponseStatus : Http.Response String -> Result Http.Error (Http.Response String)
handleResponseStatus response =
  if response.status.code >= 200 && response.status.code < 300 then
    Ok response
  else
    Err (Http.BadStatus response)


handleResponse : HttpRequest a -> Http.Response String -> Result Http.Error a
handleResponse httpRequest response =
  case httpRequest.responseHandler response of
    Ok data ->
      Ok data
    Err err ->
      Err (Http.BadPayload err response)
