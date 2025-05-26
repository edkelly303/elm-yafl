module Examples exposing
    ( FormModel
    , FormMsg
    , User
    , boolWidget
    , fields
    , firstName
    , isAdmin
    , lastName
    , nonEmptyString
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
    , isAdmin : Bool
    }


boolWidget : Yafl.Widget Bool Bool Bool
boolWidget =
    { init = ( False, Cmd.none )
    , update =
        \msg _ ->
            ( msg, Cmd.none )
    , view =
        \{ label, id } model ->
            [ H.label [ HA.for id ] [ H.text label ]
            , H.input
                [ HA.id id
                , HA.type_ "checkbox"
                , HA.checked model
                , HE.onCheck identity
                ]
                []
            ]
    , subscriptions = \_ -> Sub.none
    , submit = \model -> Ok model
    , label = "Bool"
    }



{- A basic Widget that produces a String. Its internal
   Model and Msg types are also Strings.
-}


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


fields :
    { string : Yafl.Field FormModel FormMsg Yafl.NoId String String
    , bool : Yafl.Field FormModel FormMsg Yafl.NoId Bool Bool
    }
fields =
    Yafl.defineFields
        (\string bool -> { string = string, bool = bool })
        |> Yafl.addWidget stringWidget
        |> Yafl.addWidget boolWidget
        |> Yafl.endFields


type alias FormModel =
    ( Maybe String, ( Maybe Bool, () ) )


type alias FormMsg =
    ( Maybe String, ( Maybe Bool, () ) )


nonEmptyString : Yafl.Field FormModel FormMsg Yafl.NoId String String
nonEmptyString =
    fields.string
        |> Yafl.andThen
            (\string ->
                if String.isEmpty string then
                    Yafl.fail "This field must not be blank"

                else
                    Yafl.succeed string
            )


firstName : Yafl.Field FormModel FormMsg Yafl.NoId String String
firstName =
    nonEmptyString
        |> Yafl.label "What is the user's first name?"


lastName : Yafl.Field FormModel FormMsg Yafl.NoId String String
lastName =
    nonEmptyString
        |> Yafl.label "What is the user's last name?"


isAdmin : Yafl.Field FormModel FormMsg Yafl.NoId Bool Bool
isAdmin =
    fields.bool
        |> Yafl.label "Is the user an admin?"


user : Yafl.Field FormModel FormMsg Yafl.NoId Never User
user =
    Yafl.succeed User
        |> Yafl.andMap firstName
        |> Yafl.andMap lastName
        |> Yafl.andMap isAdmin
