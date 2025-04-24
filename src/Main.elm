module Main exposing (main)

import Browser
import Html as H
import Widgets
import Yafl as Y
import YaflDebug


type alias FormMsg =
    ( Maybe String
    , ( Maybe String
      , ( Maybe Widgets.BoolMsg
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
            Y.update form
        , view =
            \model ->
                H.main_ []
                    [ H.form []
                        [ H.h1 [] [ H.text "About your dog" ]
                        , H.div [] (Y.view form model)
                        ]

                    --, YaflDebug.draw model
                    ]
        , subscriptions =
            Y.subscriptions form
        }


type alias Fields =
    { int : Y.Field FormModel FormMsg Y.NoAddress String Int
    , string : Y.Field FormModel FormMsg Y.NoAddress String String
    , bool : Y.Field FormModel FormMsg Y.NoAddress Widgets.BoolMsg Bool
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
    Y.pure Dog
        |> Y.andMap nameField
        |> Y.andMap funFactField


nameField : Y.Field FormModel FormMsg Y.NoAddress String String
nameField =
    fields.string
        |> Y.label "What is your dog's name?"


funFactField : Y.Field FormModel FormMsg Y.NoAddress Never FunFact
funFactField =
    Y.choice
        |> Y.label "A fun fact about your dog is:"
        |> Y.option "They like bones" likesBonesField
        |> Y.option "They have fleas" hasFleasField


likesBonesField : Y.Field FormModel FormMsg Y.NoAddress Widgets.BoolMsg FunFact
likesBonesField =
    fields.bool
        |> Y.map LikesBones
        |> Y.label "Do they _really_ like bones?"


hasFleasField : Y.Field FormModel FormMsg Y.NoAddress String FunFact
hasFleasField =
    fields.int
        |> Y.label "How many fleas do they have?"
        |> Y.andThen
            (\numberOfFleas ->
                if numberOfFleas < 1 then
                    Err [ "They must have at least one?!" ]

                else
                    Ok (HasFleas numberOfFleas)
            )
        |> Y.showFeedback Widgets.viewFeedback
