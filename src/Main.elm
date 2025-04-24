module Main exposing (main)

import Browser
import Html as H
import Widgets
import Yafl as Y



--import YaflDebug


type alias FormMsg =
    ( Maybe String
    , ( Maybe String
      , ( Maybe Bool
        , ()
        )
      )
    )


type alias FormModel =
    ( Maybe String
    , ( Maybe String
      , ( Maybe Bool
        , ()
        )
      )
    )


main : Program () (Y.Model FormModel) (Y.Msg FormMsg)
main = 
    Browser.element
        { init =
            \() -> Y.init form
        , update =
            \msg model ->
                let 
                    -- if we need the state of field A to depend on the state of
                    -- field B, we can intercept messages sent to field B and
                    -- then conditionally send messages to field A. Both fields
                    -- need to have addresses set with `Y.address` for this to
                    -- work.
                    prettySureThisGuyLikesBonesCmd = 
                        case Y.intercept nameField msg of
                            Just ("Boney M") -> 
                                Cmd.batch 
                                    [ Y.send likesBonesField True
                                    , Y.choose likesBonesField
                                    ]
                        
                            _ ->
                                Cmd.none

                    (newModel, cmd) = 
                        Y.update form msg model
                in
                (newModel
                , Cmd.batch [ cmd, prettySureThisGuyLikesBonesCmd ]
                )
        , view =
            \model ->
                H.main_ []
                    [ H.form []
                        [ H.h1 [] [ H.text "About your dog" ]
                        , H.div [] (Y.view form model)
                        ]
                    ]
        , subscriptions =
            Y.subscriptions form
        }

type alias Fields =
    { int : Y.Field FormModel FormMsg Y.NoAddress String Int
    , string : Y.Field FormModel FormMsg Y.NoAddress String String
    , bool : Y.Field FormModel FormMsg Y.NoAddress Bool Bool
    }


fields : Fields
fields =
    Y.defineFields Fields
        |> Y.addWidget Widgets.int
        |> Y.addWidget Widgets.string
        |> Y.addWidget Widgets.bool
        |> Y.endFields


type alias Dog =
    { name : String
    , funFact : FunFact
    }


type FunFact
    = LikesBones Bool
    | HasFleas Int


form : Y.Field FormModel FormMsg Y.NotAddressable Never Dog
form =
    Y.succeed Dog
        |> Y.andMap nameField
        |> Y.andMap funFactField


nameField : Y.Field FormModel FormMsg Y.HasAddress String String
nameField =
    fields.string
        |> Y.label "What is your dog's name?"
        -- if we want to send messages directly to this field with `Y.send`, we
        -- need to give it an address. The address can be any string, it doesn't
        -- matter what it is as long as it's unique.
        |> Y.address "name-field"


funFactField : Y.Field FormModel FormMsg Y.NoAddress Never FunFact
funFactField =
    Y.choice
        |> Y.label "A fun fact about your dog is:"
        |> Y.option "They like bones" likesBonesField
        |> Y.option "They have fleas" hasFleasField


likesBonesField : Y.Field FormModel FormMsg Y.HasAddress Bool FunFact
likesBonesField =
    fields.bool
        |> Y.map LikesBones
        |> Y.label "Do they _really_ like bones?"
        -- if we want to intercept messages sent to this field with
        -- `Y.intercept`, we need to give it an address.
        |> Y.address "likes-bones-field"


hasFleasField : Y.Field FormModel FormMsg Y.NoAddress String FunFact
hasFleasField =
    fields.int
        |> Y.label "How many fleas do they have?"
        |> Y.andThen
            (\numberOfFleas ->
                if numberOfFleas < 1 then
                    Y.fail "They must have at least one?!"

                else
                    Y.succeed (HasFleas numberOfFleas)
            )
        |> Y.showFeedback Widgets.viewFeedback
