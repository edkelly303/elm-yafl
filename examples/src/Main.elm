module Main exposing (main)

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl


main =
    Yafl.studio Debug.toString form


fields =
    Yafl.defineFields
        (\s b r -> { string = s, bool = b, radio = r })
        |> Yafl.addWidget stringWidget
        |> Yafl.addWidget boolWidget
        |> Yafl.addWidget radioWidget
        |> Yafl.endFields


type alias Person =
    { name : String
    , isCool : Foo
    }


form =
    Yafl.succeed Person
        |> Yafl.andMap name
        |> Yafl.andMap foo


type Choice output
    = Choice { chosen : Int, index : Int, maybeOutput : Maybe output }


choice :
    Yafl.Field formModel formMsg id widgetMsg Int
    -> Yafl.Field formModel formMsg id widgetMsg (Choice output)
choice field =
    Yafl.map (\chosen -> Choice { chosen = chosen, index = -1, maybeOutput = Nothing }) field


option :
    Yafl.Field formModel formMsg id widgetMsg output
    -> Yafl.Field formModel formMsg id2 widgetMsg2 (Choice output)
    -> Yafl.Field formModel formMsg id2 widgetMsg2 (Choice output)
option field choiceField =
    choiceField
        |> Yafl.andThen
            (\(Choice c) ->
                let
                    thisIndex =
                        c.index + 1
                in
                if c.chosen == thisIndex && c.maybeOutput == Nothing then
                    field
                        |> Yafl.map (\output -> Choice { c | maybeOutput = Just output, index = thisIndex })

                else
                    Yafl.succeed (Choice { c | index = thisIndex })
            )


endChoice :
    Yafl.Field formModel formMsg id widgetMsg (Choice output)
    -> Yafl.Field formModel formMsg id widgetMsg output
endChoice choiceField =
    choiceField
        |> Yafl.andThen
            (\(Choice c) ->
                case c.maybeOutput of
                    Just output ->
                        Yafl.succeed output

                    Nothing ->
                        Yafl.fail "No valid option selected"
            )


type Foo
    = Bar String
    | Baz Bool


foo =
    choice
        (fields.radio [ "Bar", "Baz" ])
        |> Yafl.label "Foo?"
        |> option (Yafl.map Bar name)
        |> option (Yafl.map Baz (fields.bool ()))
        |> endChoice


name =
    fields.string ()
        |> Yafl.label "What is their name?"
        |> Yafl.validate
            (\s ->
                if String.isEmpty s then
                    Just "Can't be blank"

                else
                    Nothing
            )


isCool =
    fields.bool ()
        |> Yafl.label "Are they cool?"
        |> Yafl.id "isCool"


hasCat =
    fields.bool ()
        |> Yafl.label "Do they have a cat?"
        |> Yafl.id "hasCat"


boolWidget : Yafl.Widget () Bool Bool Bool
boolWidget () =
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


stringWidget : Yafl.Widget () String String String
stringWidget () =
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


radioWidget : Yafl.Widget (List String) Int Int Int
radioWidget labels =
    { init = ( 0, Cmd.none )
    , update = \msg _ -> ( msg, Cmd.none )
    , view =
        \{ label, id, feedback } model ->
            [ H.label [ HA.for id ] [ H.text label ]
            , H.div []
                (List.indexedMap
                    (\idx l ->
                        H.label [ HA.class "yafl-radio-option" ]
                            [ H.input
                                [ HA.type_ "radio"
                                , HA.name label
                                , HE.onClick idx
                                , HA.checked (model == idx)
                                ]
                                []
                            , H.text l
                            ]
                    )
                    labels
                )
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
