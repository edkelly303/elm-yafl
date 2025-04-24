module Widgets exposing (..)

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl as Y


viewFeedback : List Y.Feedback -> H.Html msg
viewFeedback feedback =
    case feedback of
        [] ->
            H.text ""

        _ ->
            H.ul []
                (List.map
                    (\f ->
                        H.li
                            []
                            [ H.text f.message ]
                    )
                    feedback
                )


string : Y.Widget String String String
string =
    { init = ( "", Cmd.none )
    , update = \msg _ -> ( msg, Cmd.none )
    , view =
        \{ label } model ->
            [ H.label [ HA.for label ] [ H.text label ]
            , H.input
                [ HA.id label
                , HA.type_ "text"
                , HA.value model
                , HE.onInput identity
                ]
                []
            ]
    , submit = Ok
    , subscriptions = \_ -> Sub.none
    , label = "String"
    }


int : Y.Widget String String Int
int =
    { init = ( "", Cmd.none )
    , update = \msg _ -> ( msg, Cmd.none )
    , view =
        \{ label } model ->
            [ H.label [ HA.for label ] [ H.text label ]
            , H.input
                [ HA.id label
                , HA.type_ "text"
                , HA.value model
                , HE.onInput identity
                ]
                []
            ]
    , submit =
        \model ->
            String.toInt model
                |> Result.fromMaybe [ "This must be a whole number" ]
    , subscriptions = \_ -> Sub.none
    , label = "Int"
    }


bool : Y.Widget Bool Bool Bool
bool =
    { init = ( False, Cmd.none )
    , update =
        \msg _ ->
            ( msg, Cmd.none )
    , view =
        \{ label } model ->
            [ H.label [ HA.for label ] [ H.text label ]
            , H.input
                [ HA.id label
                , HA.type_ "checkbox"
                , HA.checked model
                , HE.onCheck identity
                ]
                []
            ]
    , submit = Ok
    , subscriptions = \_ -> Sub.none
    , label = "Bool"
    }
