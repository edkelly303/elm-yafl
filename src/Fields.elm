module Fields exposing (Model, Msg, fields)

import Widgets
import Yafl exposing (addWidget, defineFields, endFields)


type alias Model =
    ( Maybe String, ( Maybe Int, () ) )


type alias Msg =
    ( Maybe String, ( Maybe Widgets.IntMsg, () ) )


fields :
    { string : Yafl.Field Model Msg Yafl.NoId String String
    , int : Yafl.Field Model Msg Yafl.NoId Widgets.IntMsg Int
    }
fields =
    defineFields (\string int -> { string = string, int = int })
        |> addWidget Widgets.string
        |> addWidget Widgets.int
        |> endFields
