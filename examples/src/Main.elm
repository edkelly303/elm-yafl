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
        , error
        , errorAt
        , view
        , viewWizard
        , warning
        , warningAt
        )



{-
   db   d8b   db d888888b d8888b.  d888b  d88888b d888888b .d8888.
   88   I8I   88   `88'   88  `8D 88' Y8b 88'     `~~88~~' 88'  YP
   88   I8I   88    88    88   88 88      88ooooo    88    `8bo.
   Y8   I8I   88    88    88   88 88  ooo 88~~~~~    88      `Y8b.
   `8b d8'8b d8'   .88.   88  .8D 88. ~8~ 88.        88    db   8D
    `8b8' `8d8'  Y888888P Y8888D'  Y888P  Y88888P    YP    `8888Y'


-}


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
    , label = "Radio"
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
            let 
                icon {isError }= if isError then "⛔" else "⚠️" 
            in
            H.ul
                [ HA.style "list-style-type" "none"
                , HA.style "margin" "0px"
                , HA.style "padding" "0px"
                ]
                (List.map
                    (\f -> 
                        H.li [] [ H.small [] [ H.text (icon f ++ " " ++ f.message) ] ])
                    feedback
                )



{-
   d88888b d888888b d88888b db      d8888b. .d8888.
   88'       `88'   88'     88      88  `8D 88'  YP
   88ooo      88    88ooooo 88      88   88 `8bo.
   88~~~      88    88~~~~~ 88      88   88   `Y8b.
   88        .88.   88.     88booo. 88  .8D db   8D
   YP      Y888888P Y88888P Y88888P Y8888D' `8888Y'


-}


type alias FormMsg =
    ( Maybe String, ( Maybe Bool, ( Maybe Int, () ) ) )


type alias FormModel =
    ( Maybe String, ( Maybe Bool, ( Maybe Int, () ) ) )


fields :
    { string : Field FormModel FormMsg NoId String String String
    , bool : Field FormModel FormMsg NoId Bool Bool Bool
    , radio : List String -> Field FormModel FormMsg NoId Int Int Int
    }
fields =
    defineFields
        (\s b r -> { string = s, bool = b, radio = r })
        |> addWidget stringWidget
        |> addWidget boolWidget
        |> addWidgetWithConfig radioWidget
        |> endFields



{-
   d88888b  .d88b.  d8888b. .88b  d88.
   88'     .8P  Y8. 88  `8D 88'YbdP`88
   88ooo   88    88 88oobY' 88  88  88
   88~~~   88    88 88`8b   88  88  88
   88      `8b  d8' 88 `88. 88  88  88
   YP       `Y88P'  88   YD YP  YP  YP


-}


type alias Person =
    { name : String
    , numberOfPets : Int
    , address : Address
    , settings : ( Bool, Bool, Bool )
    , password : Password
    }


type Address
    = HouseName String
    | HouseNumber Int


type Password
    = Password String


form :
    Field
        FormModel
        FormMsg
        Never
        Never
        { password : Maybe String
        , settings : Maybe { three : Maybe Bool, two : Maybe Bool, one : Maybe Bool }
        , address : Maybe { selected : Maybe Int, options : Maybe { baz : Maybe String, bar : Maybe String } }
        , numberOfPets : Maybe Int
        , name : Maybe String
        }
        Person
form =
    succeed Person
        |> andMap .name name
        |> andMap .numberOfPets numberOfPets
        |> andMap .address address
        |> andMap .settings settings
        |> andMap .password password


name : Field FormModel FormMsg HasId String String String
name =
    fields.string
        |> label "What is their name?"
        |> identifier "name"
        |> error
            (\s ->
                if String.isEmpty s then
                    Just "Can't be blank"

                else
                    Nothing
            )
        |> warning (\s ->
            let len = String.length s in
            if len > 0 && len < 2 then Just "Is that their full name?" else Nothing)
        |> htmlBefore (H.h1 [] [ H.text "Let's make a Person!" ])
        |> htmlAfter (H.p [] [ H.small [] [ H.text "(and by the way, thanks for coming to my Yafl demo!)" ] ])


numberOfPets : Field FormModel FormMsg NoId Int Int Int
numberOfPets =
    fields.radio [ "No pets", "One pet", "Two pets or more" ]
        |> label "How many pets do they have?"


address :
    Field
        FormModel
        FormMsg
        Never
        Never
        { selected : Maybe Int
        , options : Maybe { baz : Maybe String, bar : Maybe String }
        }
        Address
address =
    choice
        |> label "What is their address?"
        |> option "House name" .bar (map HouseName houseName)
        |> option "House number" .baz (map HouseNumber houseNumber)
        |> andThen
            (\ad ->
                case ad of
                    HouseNumber _ ->
                        failAt houseNumber "Only named houses are allowed"

                    _ ->
                        succeed ad
            )


houseName : Field FormModel FormMsg NoId String String String
houseName =
    fields.string
        |> label "What is the name of their house?"


houseNumber : Field FormModel FormMsg HasId String String Int
houseNumber =
    fields.string
        |> label "What's their house number?"
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
        FormModel
        FormMsg
        Never
        Never
        { three : Maybe Bool
        , two : Maybe Bool
        , one : Maybe Bool
        }
        ( Bool, Bool, Bool )
settings =
    succeed (\a b c -> ( a, b, c ))
        |> andMap .one (fields.bool |> label "one")
        |> andMap .two (fields.bool |> label "two")
        |> andMap .three (fields.bool |> label "three")


password : Field FormModel FormMsg Never Never String Password
password =
    succeed (\p c -> ( p, c ))
        |> andMap .password password_
        |> andMap .confirm confirm

        |> errorAt confirm
            (\( p, c ) ->
                if p == c then
                    Nothing

                else
                    Just "Password and confirmation must match"
            )
        |> warningAt password_
            (\( p, c ) ->
                if String.length p > 12 then
                    Nothing

                else
                    Just "Passwords should be at least 12 characters long"
            )
        |> map Tuple.first
        |> map Password
        |> contraMap (\p -> { confirm = Just p, password = Just p })


password_ : Field FormModel FormMsg HasId String String String
password_ =
    fields.string
        |> identifier "password"
        |> label "What's their password?"


confirm : Field FormModel FormMsg HasId String String String
confirm =
    fields.string
        |> identifier "confirm"
        |> label "Confirm their password"



{-
   .88b  d88.  .d8b.  d888888b d8b   db
   88'YbdP`88 d8' `8b   `88'   888o  88
   88  88  88 88ooo88    88    88V8o 88
   88  88  88 88~~~88    88    88 V8o88
   88  88  88 88   88   .88.   88  V888
   YP  YP  YP YP   YP Y888888P VP   V8P


-}


type alias Model =
    { output : Result (List ( String, String )) Person
    , formModel : Yafl.Model FormModel Person
    }


type Msg
    = FormUpdated (Yafl.Msg FormMsg)
    | FormSubmitted
    | FormViewSwitched


main : Program () Model Msg
main =
    let
        _ =
            studio Debug.toString form
    in
    Browser.element
        { init =
            \() ->
                let
                    ( m1, c1 ) =
                        init form

                    ( m2, c2 ) =
                        load form
                            { name = Just "Ed"
                            , address = Nothing
                            , settings = Nothing
                            , password = Nothing
                            , numberOfPets = Nothing
                            }
                            m1
                in
                ( { output = Err [], formModel = m2 }
                , Cmd.batch [ c1, c2 ]
                    |> Cmd.map FormUpdated
                )
        , update =
            \msg model ->
                case msg of
                    FormViewSwitched ->
                        ( model, Cmd.none )

                    FormSubmitted ->
                        ( { model
                            | output = submit form model.formModel
                            , formModel = model.formModel
                          }
                        , Cmd.none
                        )

                    FormUpdated fmsg ->
                        let
                            ( newModel, cmd ) =
                                case intercept houseNumber model.formModel fmsg of
                                    Just "a" ->
                                        ( update form fmsg model.formModel |> Tuple.first
                                        , send houseNumber "b"
                                        )

                                    _ ->
                                        update form fmsg model.formModel
                        in
                        ( { model | formModel = newModel }
                        , Cmd.map FormUpdated cmd
                        )
        , view =
            \{ output, formModel } ->
                if isFormValid form then
                    let
                        wizard : Wizard FormMsg
                        wizard =
                            viewWizard form formModel
                    in
                    H.form [ HE.onSubmit FormSubmitted ]
                        ((wizard.stepView |> List.map (H.map FormUpdated))
                            ++ [ H.div []
                                    [ if wizard.stepIndex == 0 then
                                        H.button [ HA.type_ "button", HA.disabled True ] [ H.text "Back" ]

                                      else
                                        H.button [ HA.type_ "button", HE.onClick (FormUpdated (wizard.selectStepMsg (wizard.stepIndex - 1))) ] [ H.text "Back" ]
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
                                            , HE.onClick (FormUpdated (wizard.selectStepMsg (wizard.stepIndex + 1)))
                                            , HA.disabled (not wizard.isStepValid)
                                            ]
                                            [ H.text "Next" ]
                                    ]
                               , H.pre [] [ H.text (Debug.toString output) ]
                               , H.div [] [ H.a [ HA.href "https://dreampuf.github.io/GraphvizOnline" ] [ H.text "Graphviz" ] ]
                               , H.text (toDOT Debug.toString formModel)
                               , H.div [] (view form formModel) |> H.map FormUpdated
                               ]
                        )

                else
                    H.h1 [] [ H.text "Uh oh!" ]
        , subscriptions =
            \{ formModel } ->
                subscriptions form formModel
                    |> Sub.map FormUpdated
        }
