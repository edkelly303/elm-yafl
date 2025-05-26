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
        \{ label, id, feedback } model ->
            [ H.label [ HA.for id ] [ H.text label ]
            , H.input
                [ HA.id id
                , HA.type_ "text"
                , HA.value model
                , HE.onInput identity
                ]
                []
            , viewFeedback feedback
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
        \{ label, id, feedback } model ->
            [ H.label [ HA.for id ] [ H.text label ]
            , H.span [ HA.id id ]
                [ H.button
                    [ HA.type_ "button"
                    , HE.onClick Decrement
                    ]
                    [ H.text "-" ]
                , H.text (String.fromInt model)
                , H.button
                    [ HA.type_ "button"
                    , HE.onClick Increment
                    ]
                    [ H.text "+" ]
                ]
            , viewFeedback feedback
            ]
    , subscriptions = \_ -> Sub.none
    , submit = \model -> Ok model
    , label = "Int"
    }


viewFeedback : List Yafl.Feedback -> H.Html msg
viewFeedback feedback =
    case feedback of
        [] ->
            H.text ""

        _ ->
            H.ul
                [ HA.style "list-style-type" "none"
                , HA.style "margin" "0px"
                , HA.style "padding" "0px"
                ]
                (List.map
                    (\f -> H.li [] [ H.small [] [ H.text ("⚠️ " ++ f) ] ])
                    feedback
                )
