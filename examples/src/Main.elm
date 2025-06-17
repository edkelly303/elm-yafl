module Main exposing (main)

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl


main =
    Yafl.studio Debug.toString form


fields =
    Yafl.defineFields
        (\s b -> { string = s, bool = b })
        |> Yafl.addWidget stringWidget
        |> Yafl.addWidget boolWidget
        |> Yafl.endFields


type alias Person =
    { name : String
    , isCool : Foo
    }


form =
    Yafl.succeed Person
        |> Yafl.andMap name
        |> Yafl.andMap foo


choice : 
    Yafl.Field formModel formMsg id widgetMsg chosen 
    -> Yafl.Field formModel formMsg id widgetMsg ( chosen, Maybe b )
choice field =
    Yafl.map (\chosen -> ( chosen, Nothing )) field


option :
    chosen
    -> Yafl.Field formModel formMsg id widgetMsg output
    -> Yafl.Field formModel formMsg c d ( chosen, Maybe output )
    -> Yafl.Field formModel formMsg c d ( chosen, Maybe output )
option choosable field choiceField =
    choiceField
        |> Yafl.andThen
            (\( chosen, maybe ) ->
                case maybe of
                    Nothing ->
                        if choosable == chosen then
                            field |> Yafl.map (\output -> ( chosen, Just output ))

                        else
                            Yafl.succeed ( chosen, maybe )

                    Just output ->
                        Yafl.succeed ( chosen, Just output )
            )


endOptions :
    Yafl.Field formModel formMsg id widgetMsg ( chosen, Maybe output )
    -> Yafl.Field formModel formMsg id widgetMsg output
endOptions choiceField =
    choiceField
        |> Yafl.andThen
            (\( _, maybe ) ->
                        case maybe of
                            Just output ->
                                Yafl.succeed output

                            Nothing ->
                                Yafl.fail ("No valid option selected")

            )

type Foo
    = Bar String
    | Baz Bool


foo : Yafl.Field ( Maybe String, ( Maybe Bool, () ) ) ( Maybe String, ( Maybe Bool, () ) ) Yafl.NoId Bool Foo
foo =
    choice fields.bool 
        |> Yafl.label "Bar or Baz?"
        |> option True (Yafl.map Bar name |> Yafl.label "Bar")
        |> option False (Yafl.map Baz fields.bool |> Yafl.label "Baz")
        |> endOptions



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
