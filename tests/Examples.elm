module Examples exposing
    ( CounterMsg(..)
    , FormModel
    , FormMsg
    , User
    , counterWidget
    , fields
    , firstName
    , lastName
    , nonEmptyString
    , numberOfPets
    , stringWidget
    , user
    )

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Yafl


type alias User =
    { firstName : String
    , lastName : String
    , numberOfPets : Int
    }


type CounterMsg
    = Increment
    | Decrement


counterWidget : Yafl.Widget () Int CounterMsg Int
counterWidget () =
    { init = ( 0, Cmd.none )
    , update =
        \msg model ->
            case msg of
                Increment ->
                    ( model + 1, Cmd.none )

                Decrement ->
                    ( model - 1, Cmd.none )
    , view =
        \{ label, id } model ->
            [ H.label [ HA.for id ] [ H.text label ]
            , H.fieldset
                [ HA.id id ]
                [ H.button [ HA.type_ "button", HE.onClick Decrement ] [ H.text "-" ]
                , H.output [] [ H.text (String.fromInt model) ]
                , H.button [ HA.type_ "button", HE.onClick Increment ] [ H.text "+" ]
                ]
            ]
    , subscriptions = \_ -> Sub.none
    , submit = \model -> Ok model
    , label = "Counter"
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
                    (\f -> H.li [] [ H.small [] [ H.text ("⚠️ " ++ f.message) ] ])
                    feedback
                )


fields :
    { string : Yafl.Field FormModel FormMsg Yafl.NoId String String String
    , counter : Yafl.Field FormModel FormMsg Yafl.NoId CounterMsg CounterMsg Int
    }
fields =
    Yafl.defineFields
        (\string counter -> { string = string, counter = counter })
        |> Yafl.addWidget stringWidget
        |> Yafl.addWidget counterWidget
        |> Yafl.endFields


type alias FormModel =
    ( Maybe String, ( Maybe Int, () ) )


type alias FormMsg =
    ( Maybe String, ( Maybe CounterMsg, () ) )


nonEmptyString : Yafl.Field FormModel FormMsg Yafl.NoId String String String
nonEmptyString =
    fields.string
        |> Yafl.andThen
            (\string ->
                if String.isEmpty string then
                    Yafl.fail "This field must not be blank"

                else
                    Yafl.succeed string
            )


firstName : Yafl.Field FormModel FormMsg Yafl.NoId String String String
firstName =
    nonEmptyString
        |> Yafl.label "What is the user's first name?"


lastName : Yafl.Field FormModel FormMsg Yafl.NoId String String String
lastName =
    nonEmptyString
        |> Yafl.label "What is the user's last name?"


numberOfPets : Yafl.Field FormModel FormMsg Yafl.NoId CounterMsg CounterMsg Int
numberOfPets =
    fields.counter
        |> Yafl.label "How many pets do they have?"


user :
    Yafl.Field
        FormModel
        FormMsg
        Never
        Never
        { firstName : Maybe String
        , lastName : Maybe String
        , numberOfPets : Maybe CounterMsg
        }
        User
user =
    Yafl.succeed User
        |> Yafl.andMap .firstName firstName
        |> Yafl.andMap .lastName lastName
        |> Yafl.andMap .numberOfPets numberOfPets
