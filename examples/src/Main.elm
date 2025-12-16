module Main exposing (main)

import Browser
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl
    exposing
        ( Feedback
        , Field
        , HasId
        , Model
        , Msg
        , NoId
        , ViewConfig
        , Widget
        , Wizard
        , addWidget
        , addWidgetWithConfig
        , andMap
        , andThen
        , choice
        , contraMap
        , defineFields
        , endFields
        , fail
        , failAt
        , htmlAfter
        , htmlBefore
        , identifier
        , init
        , intercept
        , isFormValid
        , label
        , load
        , map
        , option
        , send
        , studio
        , submit
        , subscriptions
        , succeed
        , toDOT
        , update
        , validate
        , validateAt
        , view
        , viewWizard
        )


type alias FieldMsg =
    ( Maybe String, ( Maybe Bool, ( Maybe Int, () ) ) )


type alias FieldModel =
    ( Maybe String, ( Maybe Bool, ( Maybe Int, () ) ) )


fields :
    { string : Field FieldModel FieldMsg NoId String String String
    , bool : Field FieldModel FieldMsg NoId Bool Bool Bool
    , radio : List String -> Field FieldModel FieldMsg NoId Int Int Int
    }
fields =
    defineFields
        (\s b r -> { string = s, bool = b, radio = r })
        |> addWidget stringWidget
        |> addWidget boolWidget
        |> addWidgetWithConfig radioWidget
        |> endFields


type alias Person =
    { name : String
    , hasPets : Bool
    , address : Address
    , settings : ()
    , password : Password
    }


type Address
    = HouseName String
    | HouseNumber Int


type Password
    = Password String


form :
    Field
        FieldModel
        FieldMsg
        Never
        Never
        { password : Maybe String
        , settings : Maybe { three : Maybe Bool, two : Maybe Bool, one : Maybe Bool }
        , address : Maybe { selected : Maybe Int, options : Maybe { baz : Maybe String, bar : Maybe String } }
        , hasPets : Maybe Bool
        , name : Maybe String
        }
        Person
form =
    succeed Person
        |> andMap .name name
        |> andMap .hasPets hasPets
        |> andMap .address address
        |> andMap .settings settings
        |> andMap .password password


name : Field FieldModel FieldMsg HasId String String String
name =
    fields.string
        |> label "What is their name?"
        |> validate
            (\s ->
                if String.isEmpty s then
                    Just "Can't be blank"

                else
                    Nothing
            )
        |> identifier "name"
        |> htmlBefore (H.p [] [ H.text "Let's make a Person!" ])
        |> htmlAfter (H.p [] [ H.text "(and by the way, thanks for coming to my Yafl demo!)" ])


hasPets : Field FieldModel FieldMsg NoId Bool Bool Bool
hasPets =
    fields.bool
        |> label "Do they have pets?"


address :
    Field
        FieldModel
        FieldMsg
        Never
        Never
        { selected : Maybe Int
        , options : Maybe { baz : Maybe String, bar : Maybe String }
        }
        Address
address =
    choice
        |> label "What is their address?"
        |> option "House name" .bar (map HouseName fields.string)
        |> option "House number" .baz (map HouseNumber houseNumber)
        |> andThen
            (\ad ->
                case ad of
                    HouseNumber _ ->
                        failAt houseNumber "Only named houses are allowed"

                    _ ->
                        succeed ad
            )


houseNumber : Field FieldModel FieldMsg HasId String String Int
houseNumber =
    fields.string
        |> identifier "house-number"
        |> andThen
            (\str ->
                case String.toInt str of
                    Nothing ->
                        fail "Not a valid number"

                    Just int ->
                        succeed int
            )


settings :
    Field
        FieldModel
        FieldMsg
        Never
        Never
        { three : Maybe Bool
        , two : Maybe Bool
        , one : Maybe Bool
        }
        ()
settings =
    succeed (\_ _ _ -> ())
        |> andMap .one (fields.bool |> label "one")
        |> andMap .two (fields.bool |> label "two")
        |> andMap .three (fields.bool |> label "three")


password : Field FieldModel FieldMsg Never Never String Password
password =
    succeed (\p c -> ( p, c ))
        |> andMap .password fields.string
        |> andMap .confirm confirm
        |> validateAt confirm
            (\( p, c ) ->
                if p == c then
                    Nothing

                else
                    Just "Password and confirmation must match"
            )
        |> map Tuple.first
        |> map Password
        |> contraMap (\p -> { confirm = Just p, password = Just p })


confirm : Field FieldModel FieldMsg HasId String String String
confirm =
    fields.string
        |> identifier "confirm"


main : Program () ( Result (List ( String, String )) Person, Model FieldModel Person ) (Maybe (Msg FieldMsg))
main =
    let
        _ =
            studio Debug.toString form
    in
    Browser.element
        { init =
            \flags ->
                let
                    x : ()
                    x =
                        flags

                    ( m1, c1 ) =
                        init form

                    ( m2, c2 ) =
                        load form
                            { name = Just "Ed"
                            , address = Nothing
                            , settings = Nothing
                            , password = Nothing
                            , hasPets = Just True
                            }
                            m1
                in
                ( ( Err [], m2 )
                , Cmd.batch [ c1, c2 ] |> Cmd.map Just
                )
        , update =
            \msg ( output, fmodel ) ->
                case msg of
                    Nothing ->
                        ( ( submit form fmodel, fmodel ), Cmd.none )

                    Just fmsg ->
                        let
                            ( newModel, cmd ) =
                                case intercept houseNumber fmodel fmsg of
                                    Just "a" ->
                                        ( update form fmsg fmodel |> Tuple.first
                                        , send houseNumber "b"
                                        )

                                    _ ->
                                        update form fmsg fmodel
                        in
                        ( ( output, newModel )
                        , Cmd.map Just cmd
                        )
        , view =
            \( output, fmodel ) ->
                let
                    _ =
                        view form fmodel
                in
                if isFormValid form then
                    let
                        wizard : Wizard FieldMsg
                        wizard =
                            viewWizard form fmodel
                    in
                    H.form [ HE.onSubmit Nothing ]
                        ((wizard.stepView |> List.map (H.map Just))
                            ++ [ H.div []
                                    [ if wizard.stepIndex == 0 then
                                        H.button [ HA.type_ "button", HA.disabled True ] [ H.text "Back" ]

                                      else
                                        H.button [ HA.type_ "button", HE.onClick (Just (wizard.selectStepMsg (wizard.stepIndex - 1))) ] [ H.text "Back" ]
                                    , H.text (String.fromInt (wizard.stepIndex + 1) ++ " of " ++ String.fromInt wizard.totalSteps)
                                    , if wizard.stepIndex == wizard.totalSteps - 1 then
                                        H.input
                                            [ HA.type_ "submit"
                                            , HA.value "Submit"
                                            , HA.disabled (not wizard.isStepValid)
                                            ]
                                            []

                                      else
                                        H.button
                                            [ HA.type_ "button"
                                            , HE.onClick (Just (wizard.selectStepMsg (wizard.stepIndex + 1)))
                                            , HA.disabled (not wizard.isStepValid)
                                            ]
                                            [ H.text "Next" ]
                                    ]
                               , H.pre [] [ H.text (Debug.toString output) ]
                               , H.div [] [ H.a [ HA.href "https://dreampuf.github.io/GraphvizOnline" ] [ H.text "Graphviz" ] ]
                               , H.text (toDOT Debug.toString fmodel)
                               ]
                        )

                else
                    H.h1 [] [ H.text "Uh oh!" ]
        , subscriptions =
            \( _, fmodel ) ->
                subscriptions form fmodel
                    |> Sub.map Just
        }


boolWidget : Widget () Bool Bool Bool
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


stringWidget : Widget () String String String
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


radioWidget : Widget (List String) Int Int Int
radioWidget labels =
    { init = ( 0, Cmd.none )
    , update = \msg _ -> ( msg, Cmd.none )
    , view = radioWidgetView labels
    , subscriptions = \_ -> Sub.none
    , submit = \model -> Ok model
    , label = "String"
    }


radioWidgetView : List String -> (ViewConfig -> Int -> List (H.Html Int))
radioWidgetView labels =
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


viewFeedback : List Feedback -> H.Html msg
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
