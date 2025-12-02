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

                    ( m1, c1 ) =
                        Yafl.init form

                    ( m2, c2 ) =
                        Yafl.load form
                            { name = Just "Ed"
                            , bool = Nothing
                            , foo =
                                Just
                                    { selected = Just 1
                                    , options =
                                        Just
                                            { bar = Nothing
                                            , baz = Just False
                                            }
                                    }
                            , rec = Nothing
                            }
                            m1
                in
                ( ( Err [], m2 )
                , Cmd.batch [ c1, c2 ] |> Cmd.map Just
                )
        , update =
            \msg ( output, model ) ->
                case msg of
                    Nothing ->
                        ( ( Yafl.submit form model, model ), Cmd.none )

                    Just fmsg ->
                        Yafl.update form fmsg model
                            |> Tuple.mapSecond (Cmd.map Just)
                            |> Tuple.mapFirst (\m -> ( output, m ))
        , view =
            \( output, model ) ->
                if Yafl.isFormValid form then
                    let
                        { stepView, backMsg, nextMsg, stepIndex, totalSteps, selectStepMsg } =
                            Yafl.viewWizard form model
                    in
                    H.form [ HE.onSubmit Nothing ]
                        ((stepView |> List.map (H.map Just))
                            ++ [ H.div []
                                    [ case backMsg of
                                        Nothing ->
                                            H.button [ HA.type_ "button", HA.disabled True ] [ H.text "Back" ]

                                        Just msg ->
                                            H.button [ HA.type_ "button", HE.onClick (Just msg) ] [ H.text "Back" ]
                                    , H.text (String.fromInt (stepIndex + 1) ++ " of " ++ String.fromInt totalSteps)
                                    , case nextMsg of
                                        Nothing ->
                                            H.input [ HA.type_ "submit", HA.value "Submit" ] []

                                        Just msg ->
                                            H.button [ HA.type_ "button", HE.onClick (Just msg) ] [ H.text "Next" ]
                                    ]
                               , H.pre [] [ H.text (Debug.toString output) ]
                               , H.div [] [ H.a [ HA.href "https://dreampuf.github.io/GraphvizOnline" ] [ H.text "Graphviz" ] ]
                               , H.text (Yafl.toDOT Debug.toString model)
                               ]
                        )

                else
                    H.h1 [] [ H.text "Uh oh!" ]
        , subscriptions = \( _, model ) -> Yafl.subscriptions form model |> Sub.map Just
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
    Yafl.succeed (\a b c () -> ( a, b, c ))
        |> Yafl.andMap .name
            (name
                |> Yafl.identifier "name"
            )
        |> Yafl.html (H.h4 [] [ H.text "Here's some HTML between the fields!" ])
        |> Yafl.andMap .bool fields.bool
        |> Yafl.andMap .foo foo
        |> Yafl.andMap .rec rec
        |> Yafl.map (\( a, _, c ) -> Person a c)


rec =
    Yafl.succeed (\_ _ _ -> ())
        |> Yafl.andMap .one (fields.bool |> Yafl.label "one")
        |> Yafl.andMap .two (fields.bool |> Yafl.label "two")
        |> Yafl.andMap .three (fields.bool |> Yafl.label "three")


type Foo
    = Bar String
    | Baz Bool


foo =
    Yafl.choice
        |> Yafl.option "Bar"
            .bar
            (Yafl.map Bar
                (name
                    |> Yafl.identifier "bar-name"
                )
            )
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
