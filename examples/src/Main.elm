module Main exposing (main)

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl


main =
    form
        |> Yafl.studio Debug.toString


fields =
    Yafl.defineFields
        (\s b -> { string = s, bool = b })
        |> Yafl.addWidget stringWidget
        |> Yafl.addWidget boolWidget
        |> Yafl.endFields


type alias Person =
    { name : String, isCool : Bool, hasCat : Bool }


form =
    Yafl.succeed (\name_ (isCool_, hasCat_) -> Person name_ isCool_ hasCat_)
        |> Yafl.andMap name
        |> Yafl.andMap 
            (Yafl.succeed Tuple.pair
                |> Yafl.andMap isCool
                |> Yafl.andMap hasCat
                |> Yafl.validateAt isCool
                    (\(isCool_, hasCat_) ->
                        if isCool_ && not hasCat_ then
                            Just "How can they be cool if they don't have a cat?"

                        else
                            Nothing
                    )
            )


name =
    fields.string
        |> Yafl.label "What is their name?"
        |> Yafl.validate
            (\s ->
                if String.isEmpty s then
                    Just "Can't be blank"

                else
                    Nothing
            )


isCool =
    fields.bool
        |> Yafl.label "Are they cool?"
        |> Yafl.id "isCool"


hasCat =
    fields.bool
        |> Yafl.label "Do they have a cat?"
        |> Yafl.id "hasCat"


boolWidget : Yafl.Widget Bool Bool Bool
boolWidget =
    { init = ( False, Cmd.none )
    , update =
        \msg _ ->
            ( msg, Cmd.none )
    , view =
        \{ label, id, feedback } model ->
            [ H.label [ HA.for id ] [ H.text label ]
            , H.input
                [ HA.id id
                , HA.type_ "checkbox"
                , HA.checked model
                , HE.onCheck identity
                ]
                []
            , viewFeedback feedback
            ]
    , subscriptions = \_ -> Sub.none
    , submit = \model -> Ok model
    , label = "Bool"
    }


stringWidget : Yafl.Widget String String String
stringWidget =
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
