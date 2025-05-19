module Fields exposing (Model, Msg, fields)

import Widgets
import Yafl exposing (addWidget, defineFields, endFields)


type alias Msg =
    ( Maybe String, () )


type alias Model =
    ( Maybe String, () )


fields : { string : Yafl.Field Model Msg Yafl.NoAddress String String }
fields =
    defineFields (\string -> { string = string })
        |> addWidget Widgets.string
        |> endFields
