module Yafl exposing
    ( Widget
    , Field, defineFields, addWidget, endFields
    , Model, Msg, init, update, view, ViewConfig, Feedback, subscriptions, submit
    , succeed, fail, failAt
    , map, andThen
    , map2, andMap
    , choice, option
    , label
    , HasId, NoId, id, intercept, send, select
    , updateField, andUpdateField, selectField, andSelectField
    , toDOT
    )

{-| This library helps you build user input forms in Elm by creating and
composing self-contained [`Widget`](#Widget)s.


# Creating Widgets

[`Widget`](#Widget)s are the basic building blocks of this package. Each widget is
effectively a little Elm application, with its own `init`, `update`, `view` and
`subscriptions` functions, plus a couple of extra features.

This package doesn't supply any prebuilt widgets. Every app is unique, and
it's unlikely that a prebuilt widget would precisely fit your use case. But
the point is, this package gives you the power to create _any_ types of
widgets you choose, and compose them together very easily with minimal
boilerplate.

Nevertheless, we'll provide some code samples for a few simple widgets that we
can use in the code snippets in these docs.

    module Examples exposing (..)

    import Html as H
    import Html.Attributes as HA
    import Html.Events as HE
    import Yafl


    {- A basic Widget that produces a String. Its internal
       Model and Msg types are also Strings.
    -}
    stringWidget : Yafl.Widget String String String
    stringWidget =
        { init = ( "", Cmd.none )
        , update = \msg model -> ( msg, Cmd.none )
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
                , H.ul [] (List.map (\f -> H.li [] [ H.text f ]) feedback)
                ]
        , subscriptions = \model -> Sub.none
        , submit = \model -> Ok model
        , label = "String"
        }

    boolWidget : Yafl.Widget Bool Bool Bool
    boolWidget =
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
                , H.ul [] (List.map (\f -> H.li [] [ H.text f ]) feedback)
                ]
        , subscriptions = \_ -> Sub.none
        , submit = \model -> Ok model
        , label = "Bool"
        }

@docs Widget


# Turning Widgets into Fields

Before we can use our [`Widget`](#Widget)s to create a form, we need to convert them into
[`Field`](#Field)s. This conversion process effectively combines the internal `model` and
`msg` types of each widget to create composite types that we can use as the
top-level `model` and `msg` for the entire form.

We perform this conversion using three functions: [`defineFields`](#defineFields), [`addWidget`](#addWidget),
and [`endFields`](#endFields). The type signatures for these three functions are extremely
terrifying, but fortunately we don't need to understand them - just follow the
example below:

    module Examples exposing (Model, Msg, fields)

    import Yafl exposing (addWidget, defineFields, endFields)

    fields =
        defineFields
            (\string bool ->
                { string = string
                , bool = bool
                }
            )
            |> addWidget stringWidget
            |> addWidget boolWidget
            |> endFields

    {- This gives us the following Model and Msg types for
       our form:
    -}
    type alias FormModel =
        ( Maybe String, ( Maybe Bool, () ) )

    type alias FormMsg =
        ( Maybe String, ( Maybe Bool, () ) )

@docs Field, defineFields, addWidget, endFields


# Turning Fields into forms

Once we've defined our [`Field`](#Field)s, we can start the fun part: making forms!

Imagine we just want a simple form that allows a user to choose an `Int`:

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)
    import Html exposing (Html)

    -- We can turn any Field into a form:

    form =
        fields.bool

    -- Initialize it with `Yafl.init` to get a (model, cmd)
    -- tuple:

    init =
        Yafl.init form

    init

    --: ( Yafl.Model FormModel Bool, Cmd (Yafl.Msg FormMsg) )

    -- The form's model can then be passed to `Yafl.view`,
    -- `Yafl.update`, `Yafl.subscriptions` and `Yafl.submit`:

    model =
        Tuple.first init

    Yafl.view form model

    --: List (Html (Yafl.Msg FormMsg))

    Yafl.subscriptions form model

    --: Sub (Yafl.Msg FormMsg)

    Yafl.submit form model

    --> Ok False

@docs Model, Msg, init, update, view, ViewConfig, Feedback, subscriptions, submit


# Combining Fields


## Succeeding and failing

In addition to the [`Field`](#Field)s that you define based on your
[`Widget`](#Widget)s, the package also provides [`succeed`](#succeed) and
[`fail`](#fail), which can be useful in various ways when
used with other combinators such as [`andMap`](#andMap) and
[`andThen`](#andThen). You may be familiar with similar functions from packages
such as [`elm/json`](http://package.elm-lang.org/packages/elm/json/latest/Json-Decode#succeed).

The views of these fields return an empty Html element. When
submitted, `succeed` always returns an `Ok`, while `fail` always returns an
`Err`.

@docs succeed, fail, failAt


## Converting output types

@docs map, andThen


## Building product types

@docs map2, andMap


## Building custom types

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    type MyCustomType
        = Foo String
        | Bar Bool

    myCustomTypeField =
        Yafl.choice
            |> Yafl.option "Foo" fooField
            |> Yafl.option "Bar" barField

    fooField =
        fields.string
            |> Yafl.map Foo

    barField =
        fields.bool
            |> Yafl.map Bar

    model =
        myCustomTypeField
            |> Yafl.init
            |> Tuple.first

    Yafl.submit myCustomTypeField model

    --> Ok (Foo "")

@docs choice, option


# Customizing Fields

@docs label


# Communicating between Fields

@docs HasId, NoId, id, intercept, send, select


# Updating Fields synchronously

@docs updateField, andUpdateField, selectField, andSelectField


# Debugging

@docs toDOT

-}

import Dict
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import List.Extra
import NestedTuple as NT
import Regex
import Task


{-| Internal type, we probably don't need to expose this...
-}
type Locator
    = ByPath Path
    | ById String


type Location
    = Located Path
    | Identified Path String


type alias MaybeId =
    Maybe String


{-| The top-level model type for your form.
-}
type Model formModel output
    = Model (Node formModel)


type Node formModel
    = Value Location formModel
    | Product ProductType Location (Node formModel) (Node formModel)
    | Sum Location { selected : Int } (List ( String, Node formModel ))
    | Empty EmptyType Location


type ProductType
    = Map2
    | AndThen


type EmptyType
    = Succeed
    | Fail
    | NoValue


{-| The top-level message type for your form.
-}
type Msg formMsg
    = ValueChanged Locator formMsg
    | OptionSelected Locator
    | Noop


{-| An internal data type used to track the location of a [`Field`](#Field) within the form.
-}
type alias Path =
    List Int


{-| Forms are composed of `Field`s - this is the main data type we'll be using in this package.
-}
type Field formModel formMsg id fieldMsg output
    = Field
        { init :
            Path -> MaybeId -> ( Node formModel, Cmd (Msg formMsg) )
        , update :
            Msg formMsg
            -> Node formModel
            -> ( Node formModel, Cmd (Msg formMsg) )
        , view :
            InternalViewConfig
            -> Node formModel
            -> List (H.Html (Msg formMsg))
        , submit :
            Node formModel
            -> Result (List InternalFeedback) output
        , subscriptions :
            Node formModel
            -> Sub (Msg formMsg)
        , send : MaybeId -> fieldMsg -> Msg formMsg
        , intercept : MaybeId -> Msg formMsg -> Maybe fieldMsg
        , label : String
        , maybeId : MaybeId
        }


{-| Indicates that a [`Field`](#Field) has been given an `id`, and can therefore be
used with `intercept`, `send`, etc. See the docs for `id`.
-}
type HasId
    = HasId Never


{-| Indicates that a [`Field`](#Field) has not been given an `id`. See the docs for
`id`.
-}
type NoId
    = NoId Never


{-| The `Widget` type is very similar to the record type that you would supply
to [`Browser.element`](http://package.elm-lang.org/packages/elm/browser/latest/Browser#element) to create
an Elm [`Program`](http://package.elm-lang.org/packages/elm/core/latest/Platform#Program).
-}
type alias Widget model msg output =
    { init : ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , view : ViewConfig -> model -> List (H.Html msg)
    , submit : model -> Result (List String) output
    , subscriptions : model -> Sub msg
    , label : String
    }


{-| Configuration passed into the view of each [`Field`](#Field) in your form.
-}
type alias ViewConfig =
    { label : String
    , id : String
    , feedback : List Feedback
    }


{-| Feedback produced when the [`submit`](#submit) function on a [`Field`](#Field) returns errors.
-}
type alias Feedback =
    String


type alias InternalViewConfig =
    { label : String
    , id : String
    , feedback : List InternalFeedback
    }


type alias InternalFeedback =
    { message : String, fail : Bool, locator : Locator }



{-
   db    db .d8888. d888888b d8b   db  d888b       d88888b d888888b d88888b db      d8888b. .d8888.
   88    88 88'  YP   `88'   888o  88 88' Y8b      88'       `88'   88'     88      88  `8D 88'  YP
   88    88 `8bo.      88    88V8o 88 88           88ooo      88    88ooooo 88      88   88 `8bo.
   88    88   `Y8b.    88    88 V8o88 88  ooo      88~~~      88    88~~~~~ 88      88   88   `Y8b.
   88b  d88 db   8D   .88.   88  V888 88. ~8~      88        .88.   88.     88booo. 88  .8D db   8D
   ~Y8888P' `8888Y' Y888888P VP   V8P  Y888P       YP      Y888888P Y88888P Y88888P Y8888D' `8888Y'


-}


{-| Initialize your form

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    fields.bool
        |> Yafl.init

    --: ( Yafl.Model FormModel Bool, Cmd (Yafl.Msg FormMsg) )

-}
init : Field formModel formMsg id fieldMsg output -> ( Model formModel output, Cmd (Msg formMsg) )
init (Field field) =
    field.init [ 0 ] field.maybeId
        |> Tuple.mapFirst Model


{-| Update your form by supplying a `Msg` and `Model`
-}
update : Field formModel formMsg id fieldMsg output -> Msg formMsg -> Model formModel output -> ( Model formModel output, Cmd (Msg formMsg) )
update (Field field) msg (Model model) =
    field.update msg model
        |> Tuple.mapFirst Model


{-| View your form.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)
    import Html exposing (Html)

    form =
        fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.view form model

    --: List (Html (Yafl.Msg FormMsg))

-}
view : Field formModel formMsg id fieldMsg output -> Model formModel output -> List (H.Html (Msg formMsg))
view (Field field) (Model model) =
    let
        feedback =
            case field.submit model of
                Ok _ ->
                    []

                Err f ->
                    f
    in
    field.view
        { label = field.label
        , feedback = feedback
        , id = locationFromModel model |> locationToString
        }
        model


{-| Generate subscriptions for your form.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.subscriptions form model

    --: Sub (Yafl.Msg FormMsg)

-}
subscriptions : Field formModel formMsg id fieldMsg output -> Model formModel output -> Sub (Msg formMsg)
subscriptions (Field field) (Model model) =
    field.subscriptions model


{-| Submit your form.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form model

    --> Ok ""

-}
submit : Field formModel formMsg id fieldMsg output -> Model formModel output -> Result (List ( String, String )) output
submit (Field field) (Model model) =
    field.submit model
        |> Result.mapError (List.map (\{ message, locator } -> ( locatorToString locator, message )))


{-| Add a label to a Field

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    nameField =
        fields.string
            |> Yafl.label "What is your name?"

    nameField

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String

-}
label : String -> Field formModel formMsg id fieldMsg output -> Field formModel formMsg id fieldMsg output
label label_ (Field field) =
    Field { field | label = label_ }



{-
   d888888b d8888b.         .d8888. d88888b d8b   db d8888b.         d888888b d8b   db d888888b d88888b d8888b.  .o88b. d88888b d8888b. d888888b
     `88'   88  `8D         88'  YP 88'     888o  88 88  `8D           `88'   888o  88 `~~88~~' 88'     88  `8D d8P  Y8 88'     88  `8D `~~88~~'
      88    88   88         `8bo.   88ooooo 88V8o 88 88   88            88    88V8o 88    88    88ooooo 88oobY' 8P      88ooooo 88oodD'    88
      88    88   88           `Y8b. 88~~~~~ 88 V8o88 88   88            88    88 V8o88    88    88~~~~~ 88`8b   8b      88~~~~~ 88~~~      88
     .88.   88  .8D db      db   8D 88.     88  V888 88  .8D db        .88.   88  V888    88    88.     88 `88. Y8b  d8 88.     88         88
   Y888888P Y8888D' V8      `8888Y' Y88888P VP   V8P Y8888D' V8      Y888888P VP   V8P    YP    Y88888P 88   YD  `Y88P' Y88888P 88         YP
                     P                                        P

-}


{-| Add a unique identifier to a Field, which can be used to send and intercept
messages to that Field.

    import Yafl import Examples exposing (FormModel, FormMsg, fields)

    myField = fields.string

    myField

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String

    myFieldWithId = myField |> Yafl.id "any-string-as-long-as-it's-unique"

    myFieldWithId

    --: Yafl.Field FormModel FormMsg Yafl.HasId String String

    Yafl.send myFieldWithId "Hello!"

    --: Cmd (Yafl.Msg FormMsg)

This identifier is also used as the `id` string in [`ViewConfig`](#ViewConfig),
which is passed into the view when the Field is rendered. When defining a
Widget, you can use the `id` field of the `ViewConfig` to set the
`Html.Attributes.id` of the HTML input.

-}
id : String -> Field formModel formMsg NoId innerMsg output -> Field formModel formMsg HasId innerMsg output
id sendId_ (Field field) =
    Field { field | maybeId = Just sendId_ }


{-| Create a `Cmd` that will select a specific `option` in a `choice` Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    holyGrail =
        fields.string
            |> Yafl.id "any-string-as-long-as-it's-unique"

    myChoiceField =
        Yafl.choice
            |> Yafl.option "Cup of a carpenter" holyGrail
            |> Yafl.option "Fancy chalice" (Yafl.fail "You chose... poorly")

    Yafl.select holyGrail

    --: Cmd (Yafl.Msg FormMsg)

-}
select : Field formModel formMsg HasId innerMsg output -> Cmd (Msg msg)
select (Field field) =
    case field.maybeId of
        Just id_ ->
            Task.perform identity (Task.succeed (OptionSelected (ById id_)))

        Nothing ->
            Cmd.none


{-| Create a `Cmd` that will send a message to a specific `option` in a `choice` Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myFieldWithId =
        fields.string
            |> Yafl.id "any-string-as-long-as-it's-unique"

    Yafl.send myFieldWithId "Hello!"

    --: Cmd (Yafl.Msg FormMsg)

-}
send : Field formModel formMsg HasId innerMsg output -> innerMsg -> Cmd (Msg formMsg)
send (Field field) msg =
    Task.perform identity (Task.succeed (field.send field.maybeId msg))


{-| Intercept the top-level `Msg` sent to your form, and if it contains a message sent to the specified field, return that message.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myFieldWithId =
        fields.string
            |> Yafl.id "any-string-as-long-as-it's-unique"

    Yafl.intercept myFieldWithId

    --: Yafl.Msg FormMsg -> Maybe String

-}
intercept : Field formModel formMsg HasId innerMsg output -> Msg formMsg -> Maybe innerMsg
intercept (Field field) =
    field.intercept field.maybeId


{-| Update an individual Field within your form's `Model` by supplying a message for that Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    type Foo
        = Foo String String

    fooField =
        Yafl.map2 Foo firstField secondField

    firstField =
        fields.string
            |> Yafl.id "a-unique-string"

    secondField =
        fields.string
            |> Yafl.id "another-unique-string"

    model =
        fooField
            |> Yafl.init
            |> Tuple.first

    Yafl.submit fooField model

    --> Ok (Foo "" "")

    updatedModel =
        model
            |> Yafl.updateField firstField "Hello!"
            |> Tuple.first

    Yafl.submit fooField updatedModel

    --> Ok (Foo "Hello!" "")

-}
updateField : Field formModel formMsg HasId innerMsg output -> innerMsg -> Model formModel output2 -> ( Model formModel output2, Cmd (Msg formMsg) )
updateField (Field field) innerMsg (Model model) =
    field.update (field.send field.maybeId innerMsg) model
        |> Tuple.mapFirst Model


{-| Like `updateField`, but works on `( model, cmd )` tuples. Useful if you're chaining multiple updates.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    type Foo
        = Foo String String

    fooField =
        Yafl.map2 Foo firstField secondField

    firstField =
        fields.string
            |> Yafl.id "a-unique-string"

    secondField =
        fields.string
            |> Yafl.id "another-unique-string"

    updatedModel =
        fooField
            |> Yafl.init
            |> Yafl.andUpdateField firstField "Hello"
            |> Yafl.andUpdateField secondField "World"
            |> Tuple.first

    Yafl.submit fooField updatedModel

    --> Ok (Foo "Hello" "World")

-}
andUpdateField : Field formModel formMsg HasId innerMsg output -> innerMsg -> ( Model formModel output2, Cmd (Msg formMsg) ) -> ( Model formModel output2, Cmd (Msg formMsg) )
andUpdateField field innerMsg ( model, cmd1 ) =
    updateField field innerMsg model
        |> Tuple.mapSecond (\cmd2 -> Cmd.batch [ cmd1, cmd2 ])


{-| Select a specific `option` Field within your form's `Model`.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myFieldWithId =
        Yafl.succeed "Hurrah!"
            |> Yafl.id "any-string-as-long-as-it's-unique"

    myChoiceField =
        Yafl.choice
            |> Yafl.option "Don't pick me!" (Yafl.fail "Oh no, you failed!")
            |> Yafl.option "I'm the one!" myFieldWithId

    model =
        myChoiceField
            |> Yafl.init
            |> Tuple.first

    model
        |> Yafl.submit myChoiceField

    --> Err [ ( "0.0", "Oh no, you failed!" ) ]

    model
        |> Yafl.selectField myFieldWithId
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Ok "Hurrah!"

-}
selectField : Field formModel formMsg HasId innerMsg output -> Model formModel output2 -> ( Model formModel output2, Cmd (Msg formMsg) )
selectField (Field field) (Model model) =
    case field.maybeId of
        Just id_ ->
            let
                msg =
                    OptionSelected (ById id_)
            in
            field.update msg model
                |> Tuple.mapFirst Model

        Nothing ->
            ( Model model, Cmd.none )


{-| Like `selectField`, but works on `( model, cmd )` tuples. Useful if you're chaining multiple updates.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myFieldWithId =
        Yafl.succeed "Hurrah!"
            |> Yafl.id "any-string-as-long-as-it's-unique"

    myChoiceField =
        Yafl.choice
            |> Yafl.option "Don't pick me!" (Yafl.fail "Oh no, you failed!")
            |> Yafl.option "I'm the one!" myFieldWithId

    modelAndCmd =
        myChoiceField
            |> Yafl.init

    modelAndCmd
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Err [ ("0.0", "Oh no, you failed!" ) ]

    modelAndCmd
        |> Yafl.andSelectField myFieldWithId
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Ok "Hurrah!"

-}
andSelectField : Field formModel formMsg HasId innerMsg output -> ( Model formModel output2, Cmd (Msg formMsg) ) -> ( Model formModel output2, Cmd (Msg formMsg) )
andSelectField field ( model, cmd1 ) =
    selectField field model
        |> Tuple.mapSecond (\cmd2 -> Cmd.batch [ cmd1, cmd2 ])



{-
    .o88b.  .d88b.  .88b  d88. d8888b. d888888b d8b   db  .d8b.  d888888b  .d88b.  d8888b. .d8888.
   d8P  Y8 .8P  Y8. 88'YbdP`88 88  `8D   `88'   888o  88 d8' `8b `~~88~~' .8P  Y8. 88  `8D 88'  YP
   8P      88    88 88  88  88 88oooY'    88    88V8o 88 88ooo88    88    88    88 88oobY' `8bo.
   8b      88    88 88  88  88 88~~~b.    88    88 V8o88 88~~~88    88    88    88 88`8b     `Y8b.
   Y8b  d8 `8b  d8' 88  88  88 88   8D   .88.   88  V888 88   88    88    `8b  d8' 88 `88. db   8D
    `Y88P'  `Y88P'  YP  YP  YP Y8888P' Y888888P VP   V8P YP   YP    YP     `Y88P'  88   YD `8888Y'


-}


{-| A Field that always successfully generates the value that you supply.

    import Yafl

    form =
        Yafl.succeed "Hurrah!"

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form model

    --> Ok "Hurrah!"

-}
succeed : output -> Field formModel formMsg id fieldMsg output
succeed f =
    Field
        { init = \path maybeId -> ( Empty Succeed (newLocation path maybeId), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateSumNode locator model

                    _ ->
                        ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \_ -> Ok f
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }


{-| A Field that always fails on submission with the error message that you supply.

    import Yafl

    form =
        Yafl.fail "Oh dear!"

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form model

    --> Err [ ("0", "Oh dear!") ]

-}
fail : String -> Field formModel formMsg id fieldMsg output
fail e =
    Field
        { init = \path maybeId -> ( Empty Fail (newLocation path maybeId), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateSumNode locator model

                    _ ->
                        ( model, Cmd.none )
        , view =
            \{ feedback } _ ->
                case feedback of
                    [] ->
                        []

                    _ ->
                        [ H.ul
                            [ HA.style "list-style-type" "none"
                            , HA.style "margin" "0px"
                            , HA.style "padding" "0px"
                            ]
                            (List.map
                                (\f -> H.li [] [ H.small [] [ H.text ("⚠️ " ++ f.message) ] ])
                                feedback
                            )
                        ]
        , subscriptions = \_ -> Sub.none
        , submit =
            \model ->
                Err
                    [ { message = e
                      , fail = True
                      , locator = locationFromModel model |> locationToLocator
                      }
                    ]
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }


{-| Like `fail`, except it will display the error message on a _different_
Field. This can be useful in multi-field validation, when you have an error that
results from a combination of several fields, but you only want to display the
error message on one specific field.
-}
failAt : Field formModel formMsg HasId innerMsg1 output1 -> String -> Field formModel formMsg address2 innerMsg2 output2
failAt (Field failField) e =
    Field
        { init = \path maybeId -> ( Empty Fail (newLocation path maybeId), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateSumNode locator model

                    _ ->
                        ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit =
            \model ->
                Err
                    [ case failField.maybeId of
                        Just id_ ->
                            { message = e
                            , fail = True
                            , locator = ById id_
                            }

                        Nothing ->
                            { message = "FATAL ERROR in `failAt` function"
                            , fail = True
                            , locator = locatorFromModel model
                            }
                    ]
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }


{-| Convert the output of a [`Field`](#Field) from one type to another.

A common use case for this function is to create `Field`s that produce custom
type variants.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    -- Example 1: Creating a custom type variant

    type MyCustomType
        = Foo String

    fooField =
        Yafl.map Foo fields.string

    fooField
        |> Yafl.init
        |> Tuple.first
        |> Yafl.submit fooField

    --> Ok (Foo "")

-}
map :
    (output -> output2)
    -> Field formModel formMsg id fieldMsg output
    -> Field formModel formMsg id fieldMsg output2
map f (Field field) =
    Field
        { init = field.init
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , submit = \model -> field.submit model |> Result.map f
        , send = field.send
        , intercept = field.intercept
        , label = field.label
        , maybeId = field.maybeId
        }


{-| Combine the outputs of two [`Fields`](#Field) into a new output type.

You can use this to create tuples, records with two fields, custom type variants
with two arguments, and so on.

If you need to combine the outputs of more than two fields, check out
[`andMap`](#andMap) instead.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        Yafl.map2
            (\a b -> ( a, b ))
            fields.string
            fields.string

    model =
        Yafl.init form
            |> Tuple.first

    Yafl.submit form model

    --> Ok ( "", "" )

-}
map2 :
    (output1 -> output2 -> output3)
    -> Field formModel formMsg address1 innerMsg1 output1
    -> Field formModel formMsg address2 innerMsg2 output2
    -> Field formModel formMsg NoId Never output3
map2 f (Field field1) (Field field2) =
    Field
        { init =
            \path maybeId ->
                let
                    ( model1, cmd1 ) =
                        field1.init (0 :: path) field1.maybeId

                    ( model2, cmd2 ) =
                        field2.init (1 :: path) field2.maybeId
                in
                ( Product Map2 (newLocation path maybeId) model1 model2
                , Cmd.batch
                    [ cmd1
                    , cmd2
                    ]
                )
        , update =
            \msg model ->
                let
                    _ =
                        Debug.log "map2 model" model

                    _ =
                        Debug.log "map2 msg" msg
                in
                case model of
                    Product Map2 location model1 model2 ->
                        let
                            ( newModel1, cmd1 ) =
                                field1.update msg model1

                            ( newModel2, cmd2 ) =
                                field2.update msg model2
                        in
                        ( Product Map2 location newModel1 newModel2
                        , Cmd.batch [ cmd1, cmd2 ]
                        )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Product _ _ model1 model2 ->
                        field1.view { config | label = field1.label, id = locationFromModel model1 |> locationToString } model1
                            ++ field2.view { config | label = field2.label, id = locationFromModel model1 |> locationToString } model2

                    _ ->
                        []
        , subscriptions =
            \model ->
                case model of
                    Product _ _ model1 model2 ->
                        Sub.batch
                            [ field1.subscriptions model1
                            , field2.subscriptions model2
                            ]

                    _ ->
                        Sub.none
        , submit =
            \model ->
                case model of
                    Product _ _ model1 model2 ->
                        case ( field1.submit model1, field2.submit model2 ) of
                            ( Ok output1, Ok output2 ) ->
                                Ok (f output1 output2)

                            ( Err errs, Ok _ ) ->
                                Err errs

                            ( Ok _, Err errs ) ->
                                Err errs

                            ( Err errs1, Err errs2 ) ->
                                Err (errs2 ++ errs1)

                    _ ->
                        Err
                            [ { message = "weird map2 error"
                              , fail = True
                              , locator = locatorFromModel model
                              }
                            ]
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }


{-| Combine multiple fields. This is useful when [`map2`](#map2) isn't enough.

Use in combination with [`succeed`](#succeed).

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        Yafl.succeed (\a b c -> { firstName = a, middleName = b, lastName = c })
            |> Yafl.andMap (fields.string |> Yafl.label "First name")
            |> Yafl.andMap (fields.string |> Yafl.label "Middle name")
            |> Yafl.andMap (fields.string |> Yafl.label "Last name")

    model =
        Yafl.init form
            |> Tuple.first

    Yafl.submit form model

    --> Ok { firstName = "", middleName = "", lastName = "" }

-}
andMap :
    Field formModel formMsg address1 innerMsg1 output1
    -> Field formModel formMsg address2 innerMsg2 (output1 -> output2)
    -> Field formModel formMsg NoId Never output2
andMap (Field field1) (Field field2) =
    let
        (Field mapped) =
            map2 (\x f -> f x) (Field field1) (Field field2)
    in
    Field
        { mapped
            | view =
                \config model ->
                    case model of
                        Product _ _ model1 model2 ->
                            field2.view { config | label = field2.label, id = locationFromModel model1 |> locationToString } model2
                                ++ field1.view { config | label = field1.label, id = locationFromModel model2 |> locationToString } model1

                        _ ->
                            []
        }


{-| Check the result of submitting a [`Field`](#Field), and optionally display
another `Field`. This can be very useful for validation, or to ask the user for
more information, or to convert an existing [`Widget`](#Widget) to return a
different output type.

The [`succeed`](#succeed) and [`fail`](#fail) functions are often useful in
combination with this function.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    -- Example 1: Validating a field's output

    fields.string
        |> Yafl.label "Enter the first name of a Beatle"
        |> Yafl.andThen
            (\name ->
                if List.member name [ "John", "Paul", "George", "Ringo" ] then
                    Yafl.succeed name

                else
                    Yafl.fail "Invalid Beatle"
            )

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String

    -- Example 2: Asking the user for additional information

    fields.string
        |> Yafl.label "What would you like to say?"
        |> Yafl.andThen
            (\words ->
                if words == "Hello" then
                    fields.string
                        |> Yafl.label "Who are you saying 'Hello' to?"
                        |> Yafl.map (\moreWords -> words ++ " " ++ moreWords)

                else
                    Yafl.succeed words
            )

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String

    -- Example 3: Repurposing an existing widget

    fields.string
            |> Yafl.label "Enter a floating-point number"
            |> Yafl.andThen
                (\string ->
                    case String.toFloat string of
                        Just float ->
                            Yafl.succeed float

                        Nothing ->
                            Yafl.fail "That's not a valid float"
                )

    --: Yafl.Field FormModel FormMsg Yafl.NoId String Float

-}
andThen :
    (output -> Field formModel formMsg id2 innerMsg2 output2)
    -> Field formModel formMsg id fieldMsg output
    -> Field formModel formMsg id fieldMsg output2
andThen f (Field field) =
    Field
        { init =
            \path maybeId ->
                let
                    ( model1, cmd1 ) =
                        field.init (0 :: path) maybeId

                    ( model2, cmd2 ) =
                        let
                            path2 =
                                1 :: path
                        in
                        case field.submit model1 of
                            Ok output ->
                                let
                                    (Field field2) =
                                        f output
                                in
                                field2.init path2 field2.maybeId

                            Err _ ->
                                ( Empty NoValue (newLocation path2 Nothing), Cmd.none )

                    location =
                        newLocation path Nothing
                in
                ( Product AndThen location model1 model2
                , Cmd.batch [ cmd1, cmd2 ]
                )
        , update =
            \msg model ->
                case msg of
                    ValueChanged locator _ ->
                        let
                            updateHelper model_ =
                                case model_ of
                                    Product AndThen location model1 model2 ->
                                        if isLocated locator (locationFromModel model1) then
                                            let
                                                ( newModel1, cmd1 ) =
                                                    field.update msg model1

                                                ( newModel2, cmd2 ) =
                                                    case field.submit newModel1 of
                                                        Ok output ->
                                                            let
                                                                (Field field2) =
                                                                    f output
                                                            in
                                                            case model2 of
                                                                Empty _ location2 ->
                                                                    field2.init (locationToPath location2) field2.maybeId

                                                                _ ->
                                                                    field2.update msg model2

                                                        Err _ ->
                                                            ( model2, Cmd.none )
                                            in
                                            ( Product AndThen location newModel1 newModel2
                                            , Cmd.batch [ cmd1, cmd2 ]
                                            )

                                        else
                                            let
                                                ( newModel1, cmd1 ) =
                                                    updateHelper model1

                                                ( newModel2, cmd2 ) =
                                                    updateHelper model2
                                            in
                                            ( Product AndThen location newModel1 newModel2
                                            , Cmd.batch [ cmd1, cmd2 ]
                                            )

                                    Product Map2 location model1 model2 ->
                                        let
                                            ( newModel1, cmd1 ) =
                                                updateHelper model1

                                            ( newModel2, cmd2 ) =
                                                updateHelper model2
                                        in
                                        ( Product Map2 location newModel1 newModel2
                                        , Cmd.batch [ cmd1, cmd2 ]
                                        )

                                    Value location value ->
                                        ( Value location value, Cmd.none )

                                    Sum location meta labelsAndModels ->
                                        let
                                            ( labels, models ) =
                                                List.unzip labelsAndModels

                                            ( newModels, cmds ) =
                                                List.map updateHelper models
                                                    |> List.unzip

                                            newLabelsAndModels =
                                                List.Extra.zip labels newModels
                                        in
                                        ( Sum location meta newLabelsAndModels, Cmd.batch cmds )

                                    Empty typ location ->
                                        ( Empty typ location, Cmd.none )
                        in
                        updateHelper model

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Product _ _ model1 model2 ->
                        field.view { config | id = locationFromModel model1 |> locationToString } model1
                            ++ (case field.submit model1 of
                                    Ok output ->
                                        let
                                            (Field field2) =
                                                f output
                                        in
                                        field2.view { config | label = field2.label, id = locationFromModel model2 |> locationToString } model2

                                    Err _ ->
                                        []
                               )

                    _ ->
                        []
        , subscriptions =
            \model ->
                case model of
                    Product _ _ model1 model2 ->
                        Sub.batch
                            [ field.subscriptions model1
                            , case field.submit model1 of
                                Ok output ->
                                    let
                                        (Field field2) =
                                            f output
                                    in
                                    field2.subscriptions model2

                                Err _ ->
                                    Sub.none
                            ]

                    _ ->
                        Sub.none
        , submit =
            \model ->
                case model of
                    Product _ _ model1 model2 ->
                        field.submit model1
                            |> Result.andThen
                                (\output ->
                                    let
                                        (Field field2) =
                                            f output
                                    in
                                    field2.submit model2
                                )

                    _ ->
                        Err
                            [ { message = "Fatal error, expecting a `Both` node"
                              , locator = locatorFromModel model
                              , fail = True
                              }
                            ]
        , send = field.send
        , intercept = field.intercept
        , label = field.label
        , maybeId = field.maybeId
        }


{-| Begin defining a `choice` between multiple [`option`](#option)s.
-}
choice : Field formModel formMsg NoId Never output
choice =
    Field
        { init = \path maybeId -> ( Sum (newLocation path maybeId) { selected = 0 } [], Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \_ -> Err []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }


{-| Add an option to a [`choice`](#choice).

The option will render as an HTML radio input in the view, so you need to
provide a `String` to serve as a label, plus a `Field` that returns the actual
type you want as output.

All the `options` of a given `choice` must return the same output type,
although their internal `model` and `msg` types can be different.

If the user selects the radio button for this `option`, then the `Field`'s view
will be rendered underneath the fieldset containing the radio buttons.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    Yafl.choice
        |> Yafl.option
            "This is the label for the radio button"
            (fields.bool
                |> Yafl.label "This is a label for the `bool` field"
            )

-}
option :
    String
    -> Field formModel formMsg id fieldMsg output
    -> Field formModel formMsg NoId Never output
    -> Field formModel formMsg NoId Never output
option radioLabel (Field field) (Field choice_) =
    Field
        { init =
            \path _ ->
                case choice_.init path choice_.maybeId of
                    ( Sum location selection options, choiceCmd ) ->
                        let
                            ( fieldModel, fieldCmd ) =
                                field.init (List.length options :: path) field.maybeId
                        in
                        ( Sum location selection (( radioLabel, fieldModel ) :: options)
                        , Cmd.batch [ choiceCmd, fieldCmd ]
                        )

                    _ ->
                        field.init path field.maybeId
        , update =
            \msg model ->
                case model of
                    Sum location selection ((( fieldLabel, fieldModel ) :: choiceLabelsAndModels) as options) ->
                        let
                            fallback =
                                let
                                    ( newFieldModel, fieldCmd ) =
                                        field.update msg fieldModel

                                    ( newChoiceModels, choiceCmd ) =
                                        choice_.update msg (Sum location selection choiceLabelsAndModels)
                                in
                                case newChoiceModels of
                                    Sum _ _ options2 ->
                                        ( Sum location selection (( fieldLabel, newFieldModel ) :: options2)
                                        , Cmd.batch [ choiceCmd, fieldCmd ]
                                        )

                                    _ ->
                                        ( model, Cmd.none )
                        in
                        case msg of
                            OptionSelected locator ->
                                case List.Extra.find (\( _, optionModel ) -> isLocated locator (locationFromModel optionModel)) options of
                                    Just ( _, optionModel ) ->
                                        ( Sum location
                                            { selected =
                                                pathFromModel optionModel
                                                    |> List.head
                                                    |> Maybe.withDefault 0
                                            }
                                            options
                                        , Cmd.none
                                        )

                                    Nothing ->
                                        fallback

                            _ ->
                                fallback

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Sum location meta (( fieldLabel, fieldModel ) :: choiceModels) ->
                        let
                            radio idx lbl =
                                H.label [ HA.class "yafl-radio-option" ]
                                    [ H.input
                                        [ HA.type_ "radio"
                                        , HA.name config.label
                                        , HE.onClick (OptionSelected (ByPath (idx :: locationToPath location)))
                                        , HA.checked (meta.selected == idx)
                                        ]
                                        []
                                    , H.text lbl
                                    ]

                            labels =
                                List.map Tuple.first (List.reverse choiceModels) ++ [ fieldLabel ]
                        in
                        H.fieldset [ HA.id (locationToString location) ] (H.legend [] [ H.text config.label ] :: List.indexedMap radio labels)
                            :: (if meta.selected == List.length choiceModels then
                                    field.view { config | label = field.label, id = locationFromModel fieldModel |> locationToString } fieldModel

                                else
                                    choice_.view
                                        { config
                                            | label = choice_.label
                                            , id = "WHAT GOES HERE?" -- CHECK THIS?!!!
                                        }
                                        (Sum location meta choiceModels)
                                        |> List.drop 1
                               )

                    _ ->
                        [ H.text "error: not a OneOf" ]
        , subscriptions =
            \model ->
                case model of
                    Sum location meta (( _, fieldModel ) :: options) ->
                        Sub.batch
                            [ choice_.subscriptions (Sum location meta options)
                            , field.subscriptions fieldModel
                            ]

                    _ ->
                        Sub.none
        , submit =
            \model ->
                case model of
                    Sum location meta (( _, fieldModel ) :: options) ->
                        if meta.selected == List.length options then
                            field.submit fieldModel

                        else
                            choice_.submit (Sum location meta options)

                    _ ->
                        Err []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = choice_.label
        , maybeId = Nothing
        }



{-
   db   d8b   db d888888b d8888b.  d888b  d88888b d888888b .d8888.
   88   I8I   88   `88'   88  `8D 88' Y8b 88'     `~~88~~' 88'  YP
   88   I8I   88    88    88   88 88      88ooooo    88    `8bo.
   Y8   I8I   88    88    88   88 88  ooo 88~~~~~    88      `Y8b.
   `8b d8'8b d8'   .88.   88  .8D 88. ~8~ 88.        88    db   8D
    `8b8' `8d8'  Y888888P Y8888D'  Y888P  Y88888P    YP    `8888Y'


-}


{-| Begin a definition of the fields you want to use in your forms.
-}
defineFields :
    ctor
    ->
        { ctor : ctor
        , fields : b -> b
        , modelGetters : { focus : focus -> focus, appendToGetters : getters -> getters }
        , modelSetters : { focus : c -> c, appendToSetters : setters -> setters }
        , modelBlanks : d -> d
        , msgGetters : { focus : e -> e, appendToGetters : f -> f }
        , msgSetters : { focus : g -> g, appendToSetters : h -> h }
        , msgBlanks : i -> i
        , apply : j -> j
        }
defineFields ctor =
    { ctor = ctor
    , fields = NT.define
    , modelGetters = NT.defineGetters
    , modelSetters = NT.defineSetters
    , modelBlanks = NT.define
    , msgGetters = NT.defineGetters
    , msgSetters = NT.defineSetters
    , msgBlanks = NT.define
    , apply = NT.define
    }


{-| Add a Widget to the definition of the Fields you want to use in your forms.
-}
addWidget :
    widget
    ->
        { apply :
            ({ blankModel : formModel
             , blankMsg : b
             , ctor :
                Field formModel formMsg NoId innerMsg value -> c
             }
             -> ( formMsg -> Maybe innerMsg, tailA )
             -> ( Maybe innerMsg -> b -> formMsg, tailB )
             -> ( formModel -> Maybe a2, tailC )
             -> ( Maybe a3 -> formModel -> formModel, tailD )
             ->
                ( { init : ( a3, Cmd innerMsg )
                  , label : String
                  , submit : a2 -> Result (List String) value
                  , subscriptions : a2 -> Sub innerMsg
                  , update : innerMsg -> a2 -> ( a3, Cmd innerMsg )
                  , view :
                        ViewConfig -> a2 -> List (H.Html innerMsg)
                  }
                , tailE
                )
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , fields : ( widget, tail6 ) -> toAppender2
        , modelBlanks : ( Maybe a1, tail5 ) -> toAppender1
        , modelGetters :
            { appendToGetters : ( tuple3 -> head3, nextGetters1 ) -> toGetters1
            , focus : tuple3 -> ( head3, tail4 )
            }
        , modelSetters :
            { appendToSetters :
                ( head2 -> tuple2 -> tuple2, nextSetters1 ) -> toSetters1
            , focus :
                (( head2, tail3 ) -> ( head2, tail3 )) -> tuple2 -> tuple2
            }
        , msgBlanks : ( Maybe a, tail2 ) -> toAppender
        , msgGetters :
            { appendToGetters : ( tuple1 -> head1, nextGetters ) -> toGetters
            , focus : tuple1 -> ( head1, tail1 )
            }
        , msgSetters :
            { appendToSetters :
                ( head -> tuple -> tuple, nextSetters ) -> toSetters
            , focus : (( head, tail ) -> ( head, tail )) -> tuple -> tuple
            }
        }
    ->
        { apply :
            ({ blankModel : formModel, blankMsg : b, ctor : c }
             -> tailA
             -> tailB
             -> tailC
             -> tailD
             -> tailE
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , fields : tail6 -> toAppender2
        , modelBlanks : tail5 -> toAppender1
        , modelGetters :
            { appendToGetters : nextGetters1 -> toGetters1
            , focus : tuple3 -> tail4
            }
        , modelSetters :
            { appendToSetters : nextSetters1 -> toSetters1
            , focus : (tail3 -> tail3) -> tuple2 -> tuple2
            }
        , msgBlanks : tail2 -> toAppender
        , msgGetters :
            { appendToGetters : nextGetters -> toGetters, focus : tuple1 -> tail1 }
        , msgSetters :
            { appendToSetters : nextSetters -> toSetters
            , focus : (tail -> tail) -> tuple -> tuple
            }
        }
addWidget widget builder =
    { ctor = builder.ctor
    , fields = NT.appender widget builder.fields
    , modelGetters = NT.getter builder.modelGetters
    , modelSetters = NT.setter builder.modelSetters
    , modelBlanks = NT.appender Nothing builder.modelBlanks
    , msgGetters = NT.getter builder.msgGetters
    , msgSetters = NT.setter builder.msgSetters
    , msgBlanks = NT.appender Nothing builder.msgBlanks
    , apply = folder5 applier builder.apply
    }


{-| Finalize the definition of the Fields you want to use in your forms.
-}
endFields :
    { apply :
        (acc -> empty -> empty -> empty -> empty -> empty -> acc)
        -> { blankModel : appender1, blankMsg : appender, ctor : a }
        -> getters
        -> setters
        -> getters1
        -> setters1
        -> appender2
        -> { c | ctor : b }
    , ctor : a
    , fields : () -> appender2
    , modelBlanks : () -> appender1
    , modelGetters : { appendToGetters : () -> getters1, focus : focus3 }
    , modelSetters : { appendToSetters : () -> setters1, focus : focus2 }
    , msgBlanks : () -> appender
    , msgGetters : { appendToGetters : () -> getters, focus : focus1 }
    , msgSetters : { appendToSetters : () -> setters, focus : focus }
    }
    -> b
endFields builder =
    let
        apply =
            endFolder5 builder.apply

        msgGetters =
            NT.endGetters builder.msgGetters

        msgSetters =
            NT.endSetters builder.msgSetters

        modelGetters =
            NT.endGetters builder.modelGetters

        modelSetters =
            NT.endSetters builder.modelSetters

        fields =
            NT.endAppender builder.fields

        blankMsg =
            NT.endAppender builder.msgBlanks

        blankModel =
            NT.endAppender builder.modelBlanks
    in
    apply
        { ctor = builder.ctor
        , blankMsg = blankMsg
        , blankModel = blankModel
        }
        msgGetters
        msgSetters
        modelGetters
        modelSetters
        fields
        |> .ctor



{-
   d8888b.  .d8b.  d8888b. db   dD      .88b  d88.  .d8b.   d888b  d888888b  .o88b.
   88  `8D d8' `8b 88  `8D 88 ,8P'      88'YbdP`88 d8' `8b 88' Y8b   `88'   d8P  Y8
   88   88 88ooo88 88oobY' 88,8P        88  88  88 88ooo88 88         88    8P
   88   88 88~~~88 88`8b   88`8b        88  88  88 88~~~88 88  ooo    88    8b
   88  .8D 88   88 88 `88. 88 `88.      88  88  88 88   88 88. ~8~   .88.   Y8b  d8
   Y8888D' YP   YP 88   YD YP   YD      YP  YP  YP YP   YP  Y888P  Y888888P  `Y88P'


-}


applier :
    (formMsg -> Maybe innerMsg)
    -> (Maybe innerMsg -> b -> formMsg)
    -> (formModel -> Maybe a)
    -> (Maybe a1 -> formModel -> formModel)
    ->
        { init : ( a1, Cmd innerMsg )
        , label : String
        , submit : a -> Result (List String) value
        , subscriptions : a -> Sub innerMsg
        , update : innerMsg -> a -> ( a1, Cmd innerMsg )
        , view : ViewConfig -> a -> List (H.Html innerMsg)
        }
    ->
        { blankModel : formModel
        , blankMsg : b
        , ctor : Field formModel formMsg NoId innerMsg value -> d
        }
    -> { blankModel : formModel, blankMsg : b, ctor : d }
applier msgGetter msgSetter modelGetter modelSetter fieldType acc =
    let
        send_ msg_ =
            msgSetter (Just msg_) acc.blankMsg

        intercept_ =
            msgGetter

        wrappedFieldType =
            wrapWithTrees
                { init =
                    let
                        ( model, cmd ) =
                            fieldType.init
                    in
                    ( modelSetter (Just model) acc.blankModel
                    , Cmd.map send_ cmd
                    )
                , update =
                    \msg model ->
                        case
                            Maybe.map2 fieldType.update (msgGetter msg) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , view =
                    \config model ->
                        Maybe.map (fieldType.view config) (modelGetter model)
                            |> Maybe.withDefault []
                            |> List.map (H.map send_)
                , submit =
                    \model ->
                        modelGetter model
                            |> Maybe.map
                                (\mdl ->
                                    fieldType.submit mdl
                                        |> Result.mapError
                                            (\errs ->
                                                List.map
                                                    (\err ->
                                                        { message = err
                                                        , fail = True
                                                        , locator = ByPath []
                                                        }
                                                    )
                                                    errs
                                            )
                                )
                            |> Maybe.withDefault
                                (Err
                                    [ { message = "error in `applier` function"
                                      , fail = True
                                      , locator = ByPath []
                                      }
                                    ]
                                )
                , subscriptions =
                    \model ->
                        Maybe.map fieldType.subscriptions (modelGetter model)
                            |> Maybe.withDefault Sub.none
                            |> Sub.map send_
                , label = fieldType.label
                , send = send_
                , intercept = intercept_
                , blankModel = acc.blankModel
                }
    in
    { ctor = acc.ctor wrappedFieldType
    , blankMsg = acc.blankMsg
    , blankModel = acc.blankModel
    }


wrapWithTrees :
    { init : ( formModel, Cmd formMsg )
    , update : formMsg -> formModel -> ( formModel, Cmd formMsg )
    , blankModel : formModel
    , view : ViewConfig -> formModel -> List (H.Html formMsg)
    , submit : formModel -> Result (List InternalFeedback) value
    , subscriptions : formModel -> Sub formMsg
    , send : innerMsg -> formMsg
    , intercept : formMsg -> Maybe innerMsg
    , label : String
    }
    -> Field formModel formMsg NoId innerMsg value
wrapWithTrees args =
    Field
        { init =
            \path maybeId ->
                let
                    location =
                        newLocation path maybeId
                in
                args.init
                    |> Tuple.mapBoth
                        (\model -> Value location model)
                        (\cmd -> Cmd.map (ValueChanged (locationToLocator location)) cmd)
        , update =
            \msg model ->
                internalUpdate args.update msg model
        , view =
            \config model ->
                let
                    location =
                        locationFromModel model

                    relevantFeedback =
                        List.filterMap
                            (\f ->
                                if isLocated f.locator location then
                                    Just f.message

                                else
                                    Nothing
                            )
                            config.feedback

                    ( model_, mapper ) =
                        case model of
                            Value _ model__ ->
                                ( model__, ValueChanged (locationToLocator location) )

                            _ ->
                                ( args.blankModel, always Noop )
                in
                args.view
                    { feedback = relevantFeedback
                    , id = locationToString location
                    , label = config.label
                    }
                    model_
                    |> List.map (H.map mapper)
        , submit =
            \model ->
                case model of
                    Value location model_ ->
                        args.submit model_
                            |> Result.mapError
                                (\errs ->
                                    List.map
                                        (\err ->
                                            { err
                                                | locator = locationToLocator location
                                            }
                                        )
                                        errs
                                )

                    _ ->
                        Err []
        , subscriptions =
            \model ->
                case model of
                    Value location model_ ->
                        args.subscriptions model_
                            |> Sub.map (ValueChanged (locationToLocator location))

                    _ ->
                        Sub.none
        , send =
            \maybeId msg ->
                case maybeId of
                    Nothing ->
                        Noop

                    Just id_ ->
                        ValueChanged (ById id_) (args.send msg)
        , intercept =
            \maybeId msg ->
                case ( maybeId, msg ) of
                    ( Just id_, ValueChanged (ById msgAddress) msgTuple ) ->
                        if msgAddress == id_ then
                            args.intercept msgTuple

                        else
                            Nothing

                    _ ->
                        Nothing
        , label = args.label
        , maybeId = Nothing
        }


internalUpdate :
    (msg -> model -> ( model, Cmd a ))
    -> Msg msg
    -> Node model
    -> ( Node model, Cmd (Msg a) )
internalUpdate update_ msg model =
    case model of
        Value location innerModel ->
            case msg of
                ValueChanged locator innerMsg ->
                    if isLocated locator location then
                        let
                            ( newModel, cmd ) =
                                update_ innerMsg innerModel
                        in
                        ( Value location newModel
                        , Cmd.map (ValueChanged (locationToLocator location)) cmd
                        )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Product typ location model1 model2 ->
            let
                ( newModel1, cmd1 ) =
                    internalUpdate update_ msg model1

                ( newModel2, cmd2 ) =
                    internalUpdate update_ msg model2
            in
            ( Product typ location newModel1 newModel2
            , Cmd.batch [ cmd1, cmd2 ]
            )

        Sum location selection options ->
            let
                fallback =
                    let
                        ( labels, models ) =
                            List.unzip options

                        ( newModels, cmds ) =
                            models
                                |> List.map (internalUpdate update_ msg)
                                |> List.unzip
                    in
                    ( Sum location selection (List.Extra.zip labels newModels)
                    , Cmd.batch cmds
                    )
            in
            case msg of
                OptionSelected locator ->
                    case
                        List.Extra.findMap
                            (\( _, optionModel ) ->
                                let
                                    optionLocation =
                                        locationFromModel optionModel
                                in
                                if isLocated locator optionLocation then
                                    optionLocation
                                        |> locationToPath
                                        |> List.head

                                else
                                    Nothing
                            )
                            options
                    of
                        Just selected ->
                            ( Sum location { selected = selected } options
                            , Cmd.none
                            )

                        Nothing ->
                            fallback

                _ ->
                    fallback

        Empty _ _ ->
            ( model, Cmd.none )


locateSumNode : Locator -> Node model -> ( Node model, Cmd msg )
locateSumNode locator model =
    case model of
        Sum location selection options ->
            case
                List.Extra.findMap
                    (\( _, optionModel ) ->
                        if isLocated locator (locationFromModel optionModel) then
                            pathFromModel optionModel
                                |> List.head

                        else
                            Nothing
                    )
                    options
            of
                Just selected ->
                    ( Sum location
                        { selected = selected }
                        options
                    , Cmd.none
                    )

                Nothing ->
                    let
                        ( labels, models ) =
                            List.unzip options

                        ( newModels, cmds ) =
                            models
                                |> List.map (locateSumNode locator)
                                |> List.unzip
                    in
                    ( Sum location selection (List.Extra.zip labels newModels)
                    , Cmd.batch cmds
                    )

        Value _ _ ->
            ( model, Cmd.none )

        Product typ location model1 model2 ->
            let
                ( newModel1, cmd1 ) =
                    locateSumNode locator model1

                ( newModel2, cmd2 ) =
                    locateSumNode locator model2
            in
            ( Product typ location newModel1 newModel2
            , Cmd.batch [ cmd1, cmd2 ]
            )

        Empty _ _ ->
            ( model, Cmd.none )


folder5 :
    (headA -> headB -> headC -> headD -> headE -> accForHead -> accForTail)
    -> ((accForHead -> ( headA, tailA ) -> ( headB, tailB ) -> ( headC, tailC ) -> ( headD, tailD ) -> ( headE, tailE ) -> accForNext) -> toFolder5)
    -> (accForTail -> tailA -> tailB -> tailC -> tailD -> tailE -> accForNext)
    -> toFolder5
folder5 =
    let
        folder5_ foldHead foldTail accForHead tuple1 tuple2 tuple3 tuple4 tuple5 =
            let
                accForTail =
                    foldHead (NT.head tuple1) (NT.head tuple2) (NT.head tuple3) (NT.head tuple4) (NT.head tuple5) accForHead
            in
            foldTail accForTail (NT.tail tuple1) (NT.tail tuple2) (NT.tail tuple3) (NT.tail tuple4) (NT.tail tuple5)
    in
    do folder5_


do : (doThis -> doRest -> todoPrev) -> doThis -> (todoPrev -> done) -> doRest -> done
do doer doThis doPrev =
    \doRest -> doPrev (doer doThis doRest)


end : ender -> (ender -> done) -> done
end ender prev =
    prev ender


endFolder5 : ((acc -> empty -> empty -> empty -> empty -> empty -> acc) -> folder5) -> folder5
endFolder5 =
    end (\acc _ _ _ _ _ -> acc)



{-
   db       .d88b.   .o88b.  .d8b.  d888888b d888888b  .d88b.  d8b   db
   88      .8P  Y8. d8P  Y8 d8' `8b `~~88~~'   `88'   .8P  Y8. 888o  88
   88      88    88 8P      88ooo88    88       88    88    88 88V8o 88
   88      88    88 8b      88~~~88    88       88    88    88 88 V8o88
   88booo. `8b  d8' Y8b  d8 88   88    88      .88.   `8b  d8' 88  V888
   Y88888P  `Y88P'   `Y88P' YP   YP    YP    Y888888P  `Y88P'  VP   V8P


-}


locationToString : Location -> String
locationToString location =
    case location of
        Located path ->
            pathToString path

        Identified _ id_ ->
            id_


pathToString path =
    path
        |> List.reverse
        |> List.map String.fromInt
        |> String.join "."


newLocation : Path -> Maybe String -> Location
newLocation path maybeId =
    case maybeId of
        Nothing ->
            Located path

        Just id_ ->
            Identified path id_


locationFromModel : Node model -> Location
locationFromModel model =
    case model of
        Value loc _ ->
            loc

        Product _ loc _ _ ->
            loc

        Sum loc _ _ ->
            loc

        Empty _ loc ->
            loc


pathFromModel : Node model -> Path
pathFromModel =
    locationFromModel >> locationToPath


locationToPath : Location -> Path
locationToPath location =
    case location of
        Located path_ ->
            path_

        Identified path_ _ ->
            path_


isLocated : Locator -> Location -> Bool
isLocated locator location =
    case ( locator, location ) of
        ( ByPath path1, Located path2 ) ->
            path1 == path2

        ( ByPath path1, Identified path2 _ ) ->
            path1 == path2

        ( ById address1, Identified _ address2 ) ->
            address1 == address2

        ( ById _, Located _ ) ->
            False


locationToLocator : Location -> Locator
locationToLocator location =
    case location of
        Located path ->
            ByPath path

        Identified _ id_ ->
            ById id_


locatorFromModel : Node model -> Locator
locatorFromModel =
    locationFromModel >> locationToLocator


locatorToString : Locator -> String
locatorToString locator =
    case locator of
        ById id_ ->
            id_

        ByPath path ->
            pathToString path



{-
    d888b  d8888b.  .d8b.  d8888b. db   db db    db d888888b d88888D
   88' Y8b 88  `8D d8' `8b 88  `8D 88   88 88    88   `88'   YP  d8'
   88      88oobY' 88ooo88 88oodD' 88ooo88 Y8    8P    88       d8'
   88  ooo 88`8b   88~~~88 88~~~   88~~~88 `8b  d8'    88      d8'
   88. ~8~ 88 `88. 88   88 88      88   88  `8bd8'    .88.    d8' db
    Y888P  88   YD YP   YP 88      YP   YP    YP    Y888888P d88888P


-}


{-| Convert a `Model` value into a Graphviz DOT String, which you can visualize
using a tool such as <https://dreampuf.github.io/GraphvizOnline>

As the first argument, you should pass in `Debug.toString`.

-}
toDOT : (model -> String) -> Model model output -> String
toDOT debugToString (Model model) =
    let
        escape str =
            String.replace "\"" "\\\"" str


        regex =
            Regex.fromString "(?<=Just )[^,]+"
                |> Maybe.withDefault Regex.never

        match val =
            Regex.find regex (escape (debugToString val)) |> List.map .match |> List.head |> Maybe.withDefault ""

        bothTypeToString bothType =
            case bothType of
                Map2 ->
                    { label = "Map2", shape = "larrow" }

                AndThen ->
                    { label = "AndThen", shape = "rarrow" }

        emptyTypeToString emptyType =
            case emptyType of
                Succeed ->
                    { label = "Succeed", shape = "star" }

                Fail ->
                    { label = "Fail", shape = "octagon" }

                NoValue ->
                    { label = "No Value", shape = "plain" }

        nodeLabel loc innerLabel =
            "\"" ++ locationToString loc ++ ": " ++ innerLabel ++ "\""

        toPathsAndLabels model_ =
            case model_ of
                Value loc val ->
                    [ ( locationToPath loc
                      , nodeLabel loc ("Value: " ++ match val)
                      , "oval"
                      )
                    ]

                Product typ loc m1 m2 ->
                    ( locationToPath loc
                    , nodeLabel loc (bothTypeToString typ).label
                    , (bothTypeToString typ).shape
                    )
                        :: toPathsAndLabels m1
                        ++ toPathsAndLabels m2

                Sum loc _ ms ->
                    ( locationToPath loc
                    , nodeLabel loc "Choice"
                    , "diamond"
                    )
                        :: List.concatMap (\( _, m ) -> toPathsAndLabels m) ms

                Empty typ loc ->
                    [ ( locationToPath loc
                      , nodeLabel loc (emptyTypeToString typ).label
                      , (emptyTypeToString typ).shape
                      )
                    ]

        pathDict =
            model
                |> toPathsAndLabels
                |> List.sort
                |> List.indexedMap (\i ( p, l, c ) -> ( p, ( i, l, c ) ))
                |> Dict.fromList

        node index label_ colour =
            String.fromInt index
                ++ " [ label = "
                ++ label_
                ++ ", shape = \""
                ++ colour
                ++ "\", fixedsize = shape, style = filled, fillcolor = grey85, color = grey85 ]\n"

        edge n1 n2 =
            String.fromInt n1 ++ " -- " ++ String.fromInt n2 ++ "\n"

        ( nodes, edges ) =
            Dict.foldl
                (\path ( index, label_, colour ) list ->
                    ( node index label_ colour
                    , case Dict.get (List.drop 1 path) pathDict of
                        Just ( parentIndex, _, _ ) ->
                            edge parentIndex index

                        Nothing ->
                            ""
                    )
                        :: list
                )
                []
                pathDict
                |> List.unzip
                |> Tuple.mapBoth (List.sort >> String.concat) (List.sort >> String.concat)
    in
    "strict graph {\n" ++ nodes ++ edges ++ "}"
