module Main exposing (main)

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl
import Yafl.Loader


main =
    let
        _ =
            example
    in
    Yafl.studio Debug.toString form


fields =
    Yafl.defineFields
        (\s -> { string = s })
        |> Yafl.addWidget stringWidget
        -- |> Yafl.addWidget boolWidget
        -- |> Yafl.addWidgetWithConfig radioWidget
        |> Yafl.endFields


intL : Yafl.Loader.Loader Int ( Maybe String, () )
intL =
    Yafl.Loader.makeLoader (\i -> ( Just <| String.fromInt i, () ))


stringL : Yafl.Loader.Loader String ( Maybe String, () )
stringL =
    Yafl.Loader.makeLoader (\str -> ( Just str, () ))


type alias Person =
    { name : String

    -- , isCool : Foo
    }


form =
    Yafl.succeed Person
        |> Yafl.andMap name



-- |> Yafl.andMap foo


loader =
    Yafl.Loader.succeed
        |> Yafl.Loader.andMap .name stringL


example =
    let
        model =
            Yafl.init form
                |> Tuple.first
                |> Debug.log "model1"
    in
    Yafl.Loader.load loader { name = Just "ed" } model
        |> Debug.log "model2"


type Foo
    = Bar String
    | Baz Bool



-- foo =
--     Yafl.choice
--         |> Yafl.option "Bar" (Yafl.map Bar name)
--         |> Yafl.option "Baz" (Yafl.map Baz fields.bool)
--         |> Yafl.label "Foo?"


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
