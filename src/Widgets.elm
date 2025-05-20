module Widgets exposing (IntMsg, int, string)

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl



{- A basic Widget that produces a String. Its internal
   Model and Msg types are also Strings.
-}


string : Yafl.Widget String String String
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
    , subscriptions = \_ -> Sub.none
    , submit = \model -> Ok model
    , label = "String"
    }



{- A Widget that produces an Int. This is basically
   the 'Counter' example from the Elm Guide.
-}


type IntMsg
    = Increment
    | Decrement


int : Yafl.Widget Int IntMsg Int
int =
    { init = ( 0, Cmd.none )
    , update =
        \msg model ->
            ( case msg of
                Increment ->
                    model + 1

                Decrement ->
                    model - 1
            , Cmd.none
            )
    , view =
        \{ label } model ->
            [ H.label [ HA.for label ] [ H.text label ]
            , H.span []
                [ H.button
                    [ HA.id label
                    , HA.type_ "button"
                    , HE.onClick Decrement
                    ]
                    [ H.text "-" ]
                , H.text (String.fromInt model)
                , H.button
                    [ HA.id label
                    , HA.type_ "button"
                    , HE.onClick Increment
                    ]
                    [ H.text "+" ]
                ]
            ]
    , subscriptions = \_ -> Sub.none
    , submit = \model -> Ok model
    , label = "Int"
    }
