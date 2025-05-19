module Widgets exposing (string)

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl as Y


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
