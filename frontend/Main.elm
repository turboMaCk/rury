module Main exposing (main)

import Browser exposing (Document)
import Bytes exposing (Bytes)
import Bytes.Decode as Bytes
import File.Download as Download
import Html exposing (Html)
import Html.Attributes as Attrs
import Html.Events as Events
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData exposing (RemoteData(..), WebData)
import Search
import Set exposing (Set)


apiUrl : String
apiUrl =
    "http://localhost:3000"


type State
    = Configure
    | Building
    | Download
    | Error String


type alias Model =
    { availablePackages : WebData (List String)
    , searchTerm : String
    , selected : Set String
    , state : State
    }


init : () -> ( Model, Cmd Msg )
init () =
    ( { availablePackages = Loading
      , selected = Set.empty
      , searchTerm = ""
      , state = Configure
      }
    , Http.get
        { url = apiUrl ++ "/all-packages"
        , expect = Http.expectJson PkgListLoaded (Decode.list Decode.string)
        }
    )


type Msg
    = PkgListLoaded (Result Http.Error (List String))
    | TogglePackage String
    | SetSearchTerm String
    | BuildContainer
    | GotData (Result String Bytes)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PkgListLoaded res ->
            ( { model | availablePackages = RemoteData.fromResult res }, Cmd.none )

        TogglePackage name ->
            ( { model
                | selected =
                    if Set.member name model.selected then
                        Set.remove name model.selected

                    else
                        Set.insert name model.selected
              }
            , Cmd.none
            )

        SetSearchTerm term ->
            ( { model | searchTerm = term }
            , Cmd.none
            )

        BuildContainer ->
            let
                resolve : Http.Response Bytes -> Result String Bytes
                resolve response =
                    case response of
                        Http.GoodStatus_ metadata body ->
                            Ok body

                        Http.Timeout_ ->
                            Err "Timeout"

                        Http.BadUrl_ _ ->
                            Err "Not found"

                        Http.NetworkError_ ->
                            Err "Network down"

                        Http.BadStatus_ metadata _ ->
                            Err <| "Bad status " ++ String.fromInt metadata.statusCode
            in
            ( { model | state = Building }
            , Http.post
                { url = apiUrl ++ "/get-image"
                , body = Http.jsonBody <| Encode.list Encode.string <| Set.toList model.selected
                , expect = Http.expectBytesResponse GotData resolve
                }
            )

        GotData bytes ->
            case bytes of
                Ok data ->
                    ( { model | state = Download }
                    , Download.bytes "docker-image" "application/docker" data
                    )

                Err err ->
                    ( { model | state = Error err }, Cmd.none )


viewPackage : Model -> String -> Html Msg
viewPackage model name =
    Html.label [ Attrs.style "display" "block" ]
        [ Html.input
            [ Attrs.type_ "checkbox"
            , Attrs.checked <| Set.member name model.selected
            , Events.onClick <| TogglePackage name
            ]
            []
        , if String.length model.searchTerm > 2 then
            Html.span [] <|
                Search.highlight
                    { match = \txt -> Html.span [ Attrs.style "background" "pink" ] [ Html.text txt ]
                    , rest = Html.text
                    }
                    model.searchTerm
                    name

          else
            Html.text name
        ]


view : Model -> Html Msg
view model =
    Html.div
        [ Attrs.style "width" "800px"
        , Attrs.style "margin" "0 auto"
        ]
        [ Html.h1 [] [ Html.text "труби: R U Reproducible Yet?" ]
        , Html.div [] <|
            case model.state of
                Error msg ->
                    [ Html.h2 [] [ Html.text "Something went wrong" ]
                    , Html.p [] [ Html.text msg ]
                    ]

                Download ->
                    [ Html.h2 [] [ Html.text "Download your docker image" ]
                    , Html.p [] [ Html.text "Once downloaded load image to docker using" ]
                    , Html.pre []
                        [ Html.text "$ docker load -i docker-image" ]
                    ]

                Building ->
                    [ Html.h2 [] [ Html.text "Cooking the image..." ] ]

                Configure ->
                    [ Html.p [] [ Html.text "Select GNU R packages from crane and downlod the docker container" ]
                    , Html.input
                        [ Attrs.value model.searchTerm
                        , Events.onInput SetSearchTerm
                        ]
                        []
                    , Html.div
                        [ Attrs.style "height" "400px"
                        , Attrs.style "overflow" "auto"
                        ]
                      <|
                        case model.availablePackages of
                            Success xs ->
                                let
                                    items =
                                        if String.length model.searchTerm > 2 then
                                            Search.filter identity model.searchTerm xs

                                        else
                                            xs
                                in
                                List.map (viewPackage model) items

                            _ ->
                                []
                    , Html.button [ Events.onClick BuildContainer ] [ Html.text "Download Container" ]
                    ]
        ]



-- Main


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view =
            \model ->
                { title = "RURY"
                , body = [ view model ]
                }
        , update = update
        , subscriptions = \_ -> Sub.none
        }
