module Main exposing (main)

import Browser
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl


main =
    Browser.element
        { init =
            \flags ->
                let
                    x : ()
                    x =
                        flags
                    (m1, c1) = Yafl.init form
                    (m2, c2) = Yafl.load form 
                
                
                    
                            { name = Just ("Ed") 
                            , foo =
                                Just
                                    { selected = Just 1
                                    , options =
                                        Just
                                            { bar = Nothing
                                            , baz = Just (False)
                                            }
                                    }
                            } m1
                in
                (m2, Cmd.batch [c1, c2])
        , update = \msg model -> Yafl.update form msg model
        , view = \model -> H.form [] (Yafl.view form model)
        , subscriptions = \model -> Yafl.subscriptions form model
        }


fields =
    Yafl.defineFields
        (\s b r -> { string = s, bool = b, radio = r })
        |> Yafl.addWidget stringWidget
        |> Yafl.addWidget boolWidget
        |> Yafl.addWidgetWithConfig radioWidget
        |> Yafl.endFields


type alias Person =
    { name : String
    , isCool : Foo
    }


form =
    Yafl.succeed Tuple.pair
        |> Yafl.andMap .name name
        |> Yafl.andMap .foo foo
        |> Yafl.map (\( a, b ) -> Person a b)


type Foo
    = Bar String
    | Baz Bool


foo =
    Yafl.choice
        |> Yafl.option "Bar" .bar (Yafl.map Bar name)
        |> Yafl.option "Baz" .baz (Yafl.map Baz fields.bool)
        |> Yafl.label "Foo?"


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
