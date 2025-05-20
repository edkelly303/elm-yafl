module Yafl exposing
    ( Widget
    , Field, defineFields, addWidget, endFields
    , Model, Msg, init, update, view, ViewConfig, subscriptions, submit, Feedback, Path
    , succeed, fail
    , map, andThen
    , map2, andMap
    , choice, option
    , label, showFeedback
    , HasAddress, NoAddress, address, intercept, send, select
    , updateField, andUpdateField, selectField, andSelectField
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

    module Widgets exposing (int, string)

    import Html as H
    import Html.Attributes as HA
    import Html.Events as HE
    import Yafl


    {- A basic Widget that produces a String. Its internal
       Model and Msg types are also Strings.
    -}
    string : Yafl.Widget String String String
    string =
        { init = ( "", Cmd.none )
        , update = \msg model -> ( msg, Cmd.none )
        , view =
            \{ label } model ->
                [ H.label [ HA.for label ] [ H.text label ]
                , H.input
                    [ HA.id label
                    , HA.type_ "text"
                    , HA.value model
                    , HE.onInput identity
                    ]
                    []
                ]
        , subscriptions = \model -> Sub.none
        , submit = \model -> Ok model
        , label = "String"
        }

    {- A Widget that produces an Int. This is basically
       the 'Counter' example from the Elm Guide.
    -}
    type IntMsg
        = Increment
        | Decrement

    int : Yafl.Widget Int IntMsg Int
    int =
        { init = ( 0, Cmd.none )
        , update =
            \msg model ->
                ( case msg of
                    Increment ->
                        model + 1

                    Decrement ->
                        model - 1
                , Cmd.none
                )
        , view =
            \{ label } model ->
                [ H.label [ HA.for label ] [ H.text label ]
                , H.span []
                    [ H.button
                        [ HA.id label
                        , HA.type_ "button"
                        , HE.onClick Decrement
                        ]
                        [ H.text "-" ]
                    , H.text (String.fromInt model)
                    , H.button
                        [ HA.id label
                        , HA.type_ "button"
                        , HE.onClick Increment
                        ]
                        [ H.text "+" ]
                    ]
                ]
        , subscriptions = \model -> Sub.none
        , submit = \model -> Ok model
        , label = "Int"
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

    module Fields exposing (Model, Msg, fields)

    import Widgets
    import Yafl exposing (addWidget, defineFields, endFields)

    fields =
        defineFields
            (\string int ->
                { string = string
                , int = int
                }
            )
            |> addWidget Widgets.string
            |> addWidget Widgets.int
            |> endFields

    {- This gives us the following Model and Msg types for
       our form:
    -}
    type alias Model =
        ( Maybe String, ( Maybe Int, () ) )

    type alias Msg =
        ( Maybe String, ( Maybe Widgets.IntMsg, () ) )

@docs Field, defineFields, addWidget, endFields


# Turning Fields into forms

Once we've defined our [`Field`](#Field)s, we can start the fun part: making forms!

Imagine we just want a simple form that allows a user to choose an `Int`:

    import Yafl
    import Fields
    import Html exposing (Html)

    -- We can turn any Field into a form:

    form =
        Fields.fields.int

    -- Initialize it with `Yafl.init` to get a (model, cmd)
    -- tuple:

    init =
        Yafl.init form

    init

    --: ( Yafl.Model Fields.Model, Cmd (Yafl.Msg Fields.Msg) )

    -- The form's model can then be passed to `Yafl.view`,
    -- `Yafl.update`, `Yafl.subscriptions` and `Yafl.submit`:

    model =
        Tuple.first init

    Yafl.view form model

    --: List (Html (Yafl.Msg Fields.Msg))

    Yafl.subscriptions form model

    --: Sub (Yafl.Msg Fields.Msg)

    Yafl.submit form model

    --> Ok 0

@docs Model, Msg, init, update, view, ViewConfig, subscriptions, submit, Feedback, Path


# Combining Fields


## Succeeding and failing

In addition to the [`Field`](#Field)s that you define based on your
[`Widget`](#Widget)s, the package also provides [`succeed`](#succeed) and
[`fail`](#fail), which can be useful in various ways when
used with other combinators such as [`andMap`](#andMap) and
[`andThen`](#andThen). You may be familiar with similar functions from packages
such as [`elm/json`](/packages/elm/json/latest/Json-Decode#succeed).

The views of these fields return an empty Html element. When
submitted, `succeed` always returns an `Ok`, while `fail` always returns an
`Err`.

@docs succeed, fail


## Converting output types

@docs map, andThen


## Building product types

@docs map2, andMap


## Building custom types

    import Yafl
    import Fields

    type MyCustomType
        = Foo String
        | Bar Int

    myCustomTypeField =
        Yafl.choice
            |> Yafl.option "Foo" fooField
            |> Yafl.option "Bar" barField

    fooField =
        Fields.fields.string
            |> Yafl.map Foo

    barField =
        Fields.fields.int
            |> Yafl.map Bar

    model =
        myCustomTypeField
            |> Yafl.init
            |> Tuple.first

    Yafl.submit myCustomTypeField model

    --> Ok (Foo "")

@docs choice, option


# Customizing Fields

@docs label, showFeedback


# Communicating between Fields

@docs HasAddress, NoAddress, address, intercept, send, select


# Updating Fields synchronously

@docs updateField, andUpdateField, selectField, andSelectField

-}

import Html as H
import Html.Attributes as HA
import Html.Events as HE
import Internal exposing (Locator(..), MaybeAddress, Model(..), Msg(..), Path)
import List.Extra
import Location
import NestedTuple as NT
import Task


{-| The top-level model type for your form.
-}
type alias Model model =
    Internal.Model model


{-| The top-level message type for your form.
-}
type alias Msg msg =
    Internal.Msg msg


{-| An internal data type used to track the location of a [`Field`](#Field) within the form.
-}
type alias Path =
    Internal.Path


{-| Forms are composed of `Field`s - this is the main data type we'll be using in this package.
-}
type Field model msg address innerMsg output
    = Field
        { init :
            Path -> MaybeAddress -> ( Model model, Cmd (Msg msg) )
        , update :
            Msg msg
            -> Model model
            -> ( Model model, Cmd (Msg msg) )
        , view :
            ViewConfig
            -> Model model
            -> List (H.Html (Msg msg))
        , submit :
            Model model
            -> Result (List Feedback) output
        , subscriptions :
            Model model
            -> Sub (Msg msg)
        , send : MaybeAddress -> innerMsg -> Msg msg
        , intercept : MaybeAddress -> Msg msg -> Maybe innerMsg
        , label : String
        , maybeAddress : MaybeAddress
        }


{-| Indicates that a [`Field`](#Field) has been given an `address`, and can therefore be
used with `intercept`, `send`, etc. See the docs for `address`.
-}
type HasAddress
    = HasAddress Never


{-| Indicates that a [`Field`](#Field) has not been given an `address`. See the docs for
`address`.
-}
type NoAddress
    = NoAddress Never


{-| The `Widget` type is very similar to the record type that you would supply
to [`Browser.element`](/packages/elm/browser/latest/Browser#element) to create
an Elm [`Program`](/packages/elm/core/latest/Platform#Program).
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
    , feedback : List Feedback
    }


{-| Feedback produced when running the [`submit`](#submit) function on your form returns errors.
-}
type alias Feedback =
    { message : String, fail : Bool, path : Path }



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
    import Fields

    Fields.fields.int
        |> Yafl.init

    --: ( Yafl.Model Fields.Model, Cmd (Yafl.Msg Fields.Msg) )

-}
init : Field model msg address innerMsg output -> ( Model model, Cmd (Msg msg) )
init (Field field) =
    field.init [ 0 ] field.maybeAddress


{-| Update your form by supplying a `Msg` and `Model`
-}
update : Field model msg address innerMsg output -> Msg msg -> Model model -> ( Model model, Cmd (Msg msg) )
update (Field field) msg model =
    field.update msg model


{-| View your form.

    import Yafl
    import Fields
    import Html exposing (Html)

    form =
        Fields.fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.view form model

    --: List (Html (Yafl.Msg Fields.Msg))

-}
view : Field model msg address innerMsg output -> Model model -> List (H.Html (Msg msg))
view (Field field) model =
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
        }
        model


{-| Generate subscriptions for your form.

    import Yafl
    import Fields

    form =
        Fields.fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.subscriptions form model

    --: Sub (Yafl.Msg Fields.Msg)

-}
subscriptions : Field model msg address innerMsg output -> Model model -> Sub (Msg msg)
subscriptions (Field field) model =
    field.subscriptions model


{-| Submit your form.

    import Yafl
    import Fields

    form =
        Fields.fields.string

    model =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form model

    --> Ok ""

-}
submit : Field model msg address innerMsg output -> Model model -> Result (List Feedback) output
submit (Field field) model =
    field.submit model


{-| Add a label to a Field

    import Yafl
    import Fields

    nameField =
        Fields.fields.string
            |> Yafl.label "What is your name?"

    nameField

    --: Yafl.Field Fields.Model Fields.Msg Yafl.NoAddress String String

-}
label : String -> Field model msg address innerMsg output -> Field model msg address innerMsg output
label label_ (Field field) =
    Field { field | label = label_ }



{-
    .d8b.  d8888b. d8888b. d8888b. d88888b .d8888. .d8888. d888888b d8b   db  d888b
   d8' `8b 88  `8D 88  `8D 88  `8D 88'     88'  YP 88'  YP   `88'   888o  88 88' Y8b
   88ooo88 88   88 88   88 88oobY' 88ooooo `8bo.   `8bo.      88    88V8o 88 88
   88~~~88 88   88 88   88 88`8b   88~~~~~   `Y8b.   `Y8b.    88    88 V8o88 88  ooo
   88   88 88  .8D 88  .8D 88 `88. 88.     db   8D db   8D   .88.   88  V888 88. ~8~
   YP   YP Y8888D' Y8888D' 88   YD Y88888P `8888Y' `8888Y' Y888888P VP   V8P  Y888P


-}


{-| Add a unique identifier to a Field, which can be used to send and intercept messages to that Field.

    import Yafl
    import Fields

    myField =
        Fields.fields.string

    myField

    --: Yafl.Field Fields.Model Fields.Msg Yafl.NoAddress String String

    myAddressedField =
        myField
            |> Yafl.address "any-string-as-long-as-it's-unique"

    myAddressedField

    --: Yafl.Field Fields.Model Fields.Msg Yafl.HasAddress String String

    Yafl.send myAddressedField "Hello!"

    --: Cmd (Yafl.Msg Fields.Msg)

-}
address : String -> Field model msg NoAddress innerMsg output -> Field model msg HasAddress innerMsg output
address sendId_ (Field field) =
    Field { field | maybeAddress = Just sendId_ }


{-| Create a `Cmd` that will select a specific `option` in a `choice` Field.

    import Yafl
    import Fields

    holyGrail =
        Fields.fields.string
            |> Yafl.address "any-string-as-long-as-it's-unique"

    myChoiceField =
        Yafl.choice
            |> Yafl.option "Cup of a carpenter" holyGrail
            |> Yafl.option "Fancy chalice" (Yafl.fail "You chose... poorly")

    Yafl.select holyGrail

    --: Cmd (Yafl.Msg Fields.Msg)

-}
select : Field model msg HasAddress innerMsg output -> Cmd (Msg msg)
select (Field field) =
    case field.maybeAddress of
        Just address_ ->
            Task.perform identity (Task.succeed (OptionSelected (ByAddress address_)))

        Nothing ->
            Cmd.none


{-| Create a `Cmd` that will send a message to a specific `option` in a `choice` Field.

    import Yafl
    import Fields

    myAddressedField =
        Fields.fields.string
            |> Yafl.address "any-string-as-long-as-it's-unique"

    Yafl.send myAddressedField "Hello!"

    --: Cmd (Yafl.Msg Fields.Msg)

-}
send : Field model msg HasAddress innerMsg output -> innerMsg -> Cmd (Msg msg)
send (Field field) msg =
    Task.perform identity (Task.succeed (field.send field.maybeAddress msg))


{-| Intercept the top-level `Msg` sent to your form, and if it contains a message sent to the specified field, return that message.

    import Yafl
    import Fields

    myAddressedField =
        Fields.fields.string
            |> Yafl.address "any-string-as-long-as-it's-unique"

    Yafl.intercept myAddressedField

    --: Yafl.Msg Fields.Msg -> Maybe String

-}
intercept : Field model msg HasAddress innerMsg output -> Msg msg -> Maybe innerMsg
intercept (Field field) =
    field.intercept field.maybeAddress


{-| Update an individual Field within your form's `Model` by supplying a message for that Field.

    import Yafl
    import Fields

    type Foo
        = Foo String String

    fooField =
        Yafl.map2 Foo firstField secondField

    firstField =
        Fields.fields.string
            |> Yafl.address "a-unique-string"

    secondField =
        Fields.fields.string
            |> Yafl.address "another-unique-string"

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
updateField : Field model msg HasAddress innerMsg output -> innerMsg -> Model model -> ( Model model, Cmd (Msg msg) )
updateField (Field field) innerMsg model =
    field.update (field.send field.maybeAddress innerMsg) model


{-| Like `updateField`, but works on `( model, cmd )` tuples. Useful if you're chaining multiple updates.

    import Yafl
    import Fields
    import Cmd.Extra

    type Foo
        = Foo String String

    fooField =
        Yafl.map2 Foo firstField secondField

    firstField =
        Fields.fields.string
            |> Yafl.address "a-unique-string"

    secondField =
        Fields.fields.string
            |> Yafl.address "another-unique-string"

    updatedModel =
        fooField
            |> Yafl.init
            |> Yafl.andUpdateField firstField "Hello"
            |> Yafl.andUpdateField secondField "World"
            |> Tuple.first

    Yafl.submit fooField updatedModel

    --> Ok (Foo "Hello" "World")

-}
andUpdateField : Field model msg HasAddress innerMsg output -> innerMsg -> ( Model model, Cmd (Msg msg) ) -> ( Model model, Cmd (Msg msg) )
andUpdateField field innerMsg ( model, cmd1 ) =
    updateField field innerMsg model
        |> Tuple.mapSecond (\cmd2 -> Cmd.batch [ cmd1, cmd2 ])


{-| Select a specific `option` Field within your form's `Model`.

    import Yafl
    import Fields

    myAddressedField =
        Yafl.succeed "Hurrah!"
            |> Yafl.address "any-string-as-long-as-it's-unique"

    myChoiceField =
        Yafl.choice
            |> Yafl.option "Don't pick me!" (Yafl.fail "Oh no, you failed!")
            |> Yafl.option "I'm the one!" myAddressedField

    model =
        myChoiceField
            |> Yafl.init
            |> Tuple.first

    model
        |> Yafl.submit myChoiceField

    --> Err [ { message = "Oh no, you failed!", fail = True, path = [ 0, 0 ] } ]

    model
        |> Yafl.selectField myAddressedField
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Ok "Hurrah!"

-}
selectField : Field model msg HasAddress innerMsg output -> Model model -> ( Model model, Cmd (Msg msg) )
selectField (Field field) model =
    case field.maybeAddress of
        Just address_ ->
            let
                msg =
                    OptionSelected (ByAddress address_)
            in
            field.update msg model

        Nothing ->
            ( model, Cmd.none )


{-| Like `selectField`, but works on `( model, cmd )` tuples. Useful if you're chaining multiple updates.

    import Yafl
    import Fields

    myAddressedField =
        Yafl.succeed "Hurrah!"
            |> Yafl.address "any-string-as-long-as-it's-unique"

    myChoiceField =
        Yafl.choice
            |> Yafl.option "Don't pick me!" (Yafl.fail "Oh no, you failed!")
            |> Yafl.option "I'm the one!" myAddressedField

    modelAndCmd =
        myChoiceField
            |> Yafl.init

    modelAndCmd
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Err [ { message = "Oh no, you failed!", fail = True, path = [ 0, 0 ] } ]

    modelAndCmd
        |> Yafl.andSelectField myAddressedField
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Ok "Hurrah!"

-}
andSelectField : Field model msg HasAddress innerMsg output -> ( Model model, Cmd (Msg msg) ) -> ( Model model, Cmd (Msg msg) )
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
succeed : output -> Field model msg address innerMsg output
succeed f =
    Field
        { init = \path maybeAddress -> ( Empty (Location.new path maybeAddress), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateOneOf locator model

                    _ ->
                        ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \_ -> Ok f
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
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

    --> Err [ { message = "Oh dear!", path = [ 0 ], fail = True } ]

-}
fail : String -> Field model msg address innerMsg output
fail e =
    Field
        { init = \path maybeAddress -> ( Empty (Location.new path maybeAddress), Cmd.none )
        , update =
            \msg model ->
                case msg of
                    OptionSelected locator ->
                        locateOneOf locator model

                    _ ->
                        ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit =
            \model ->
                Err
                    [ { message = e
                      , fail = True
                      , path = Location.pathFromModel model
                      }
                    ]
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
        }


{-| Convert the output of a [`Field`](#Field) from one type to another.

A common use case for this function is to create `Field`s that produce custom
type variants.

    import Yafl
    import Fields

    -- Example 1: Creating a custom type variant

    type MyCustomType
        = Foo String

    fooField =
        Yafl.map Foo Fields.fields.string

    fooField
        |> Yafl.init
        |> Tuple.first
        |> Yafl.submit fooField

    --> Ok (Foo "")

-}
map :
    (output -> output2)
    -> Field model msg address innerMsg output
    -> Field model msg address innerMsg output2
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
        , maybeAddress = field.maybeAddress
        }


{-| Combine the outputs of two [`Fields`](#Field) into a new output type.

You can use this to create tuples, records with two fields, custom type variants
with two arguments, and so on.

If you need to combine the outputs of more than two fields, check out
[`andMap`](#andMap) instead.

    import Yafl
    import Fields

    form =
        Yafl.map2
            (\a b -> ( a, b ))
            (Fields.fields.string)
            (Fields.fields.string)

    model =
        Yafl.init form
            |> Tuple.first

    Yafl.submit form model

    --> Ok ( "", "" )

-}
map2 :
    (output1 -> output2 -> output3)
    -> Field model msg address1 innerMsg1 output1
    -> Field model msg address2 innerMsg2 output2
    -> Field model msg NoAddress Never output3
map2 f (Field field1) (Field field2) =
    Field
        { init =
            \path maybeAddress ->
                let
                    ( model1, cmd1 ) =
                        field1.init (0 :: path) field1.maybeAddress

                    ( model2, cmd2 ) =
                        field2.init (1 :: path) field2.maybeAddress
                in
                ( Both (Location.new path maybeAddress) model1 model2
                , Cmd.batch
                    [ cmd1
                    , cmd2
                    ]
                )
        , update =
            \msg model ->
                case model of
                    Both location model1 model2 ->
                        let
                            ( newModel1, cmd1 ) =
                                field1.update msg model1

                            ( newModel2, cmd2 ) =
                                field2.update msg model2
                        in
                        ( Both location newModel1 newModel2
                        , Cmd.batch
                            [ cmd1, cmd2 ]
                        )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Both _ model1 model2 ->
                        field1.view { config | label = field1.label } model1
                            ++ field2.view { config | label = field2.label } model2

                    _ ->
                        []
        , subscriptions =
            \model ->
                case model of
                    Both _ model1 model2 ->
                        Sub.batch
                            [ field1.subscriptions model1
                            , field2.subscriptions model2
                            ]

                    _ ->
                        Sub.none
        , submit =
            \model ->
                case model of
                    Both _ model1 model2 ->
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
                        Err [ { message = "weird map2 error", fail = True, path = [] } ]
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
        }


{-| Combine multiple fields. This is useful when [`map2`](#map2) isn't enough.

Use in combination with [`succeed`](#succeed).

    import Yafl
    import Fields

    form =
        Yafl.succeed (\a b c -> { firstName = a, middleName = b, lastName = c })
            |> Yafl.andMap (Fields.fields.string |> Yafl.label "First name")
            |> Yafl.andMap (Fields.fields.string |> Yafl.label "Middle name")
            |> Yafl.andMap (Fields.fields.string |> Yafl.label "Last name")

    model =
        Yafl.init form
            |> Tuple.first

    Yafl.submit form model

    --> Ok { firstName = "", middleName = "", lastName = "" }

-}
andMap :
    Field model msg address1 innerMsg1 output1
    -> Field model msg address2 innerMsg2 (output1 -> output2)
    -> Field model msg NoAddress Never output2
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
                        Both _ model1 model2 ->
                            field2.view { config | label = field2.label } model2
                                ++ field1.view { config | label = field1.label } model1

                        _ ->
                            []
        }


{-| Check the result of submitting a [`Field`](#Field), and optionally display 
another `Field`. This can be very useful for validation, or to ask the user for 
more information, or to convert an existing [`Widget`](#Widget) to return a 
different output type.

The [`succeed`](#succeed) and [`fail`](#fail) functions are often useful in 
combination with this function.

    import Fields
    import Yafl

    -- Example 1: Validating a field's output

    Fields.fields.string
        |> Yafl.label "Enter the first name of a Beatle"
        |> Yafl.andThen
            (\name ->
                if List.member name [ "John", "Paul", "George", "Ringo" ] then
                    Yafl.succeed name

                else
                    Yafl.fail "Invalid Beatle"
            )

    --: Yafl.Field Fields.Model Fields.Msg Yafl.NoAddress String String

    -- Example 2: Asking the user for additional information

    Fields.fields.string
        |> Yafl.label "What would you like to say?"
        |> Yafl.andThen
            (\words ->
                if words == "Hello" then
                    Fields.fields.string
                        |> Yafl.label "Who are you saying 'Hello' to?"
                        |> Yafl.map (\moreWords -> words ++ " " ++ moreWords)

                else
                    Yafl.succeed words
            )

    --: Yafl.Field Fields.Model Fields.Msg Yafl.NoAddress String String

    -- Example 3: Repurposing an existing widget

    Fields.fields.string
            |> Yafl.label "Enter a floating-point number"
            |> Yafl.andThen
                (\string ->
                    case String.toFloat string of
                        Just float ->
                            Yafl.succeed float

                        Nothing ->
                            Yafl.fail "That's not a valid float"
                )

    --: Yafl.Field Fields.Model Fields.Msg Yafl.NoAddress String Float

-}
andThen :
    (output -> Field model msg address innerMsg2 output2)
    -> Field model msg address innerMsg output
    -> Field model msg address innerMsg output2
andThen f (Field field) =
    Field
        { init =
            \path maybeAddress ->
                let
                    ( model1, cmd1 ) =
                        field.init (0 :: path) field.maybeAddress

                    ( model2, cmd2 ) =
                        case field.submit model1 of
                            Ok output ->
                                let
                                    (Field field2) =
                                        f output
                                in
                                field2.init (1 :: path) field2.maybeAddress

                            Err _ ->
                                ( Empty (Location.new (1 :: path) Nothing), Cmd.none )
                in
                ( Both (Location.new path maybeAddress) model1 model2
                , Cmd.batch [ cmd1, cmd2 ]
                )
        , update =
            \msg model ->
                case model of
                    Both location model1 model2 ->
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
                                            Empty _ ->
                                                field2.init (1 :: Location.pathFromModel model) field2.maybeAddress

                                            _ ->
                                                field2.update msg model2

                                    Err _ ->
                                        ( model2, Cmd.none )
                        in
                        ( Both location newModel1 newModel2
                        , Cmd.batch [ cmd1, cmd2 ]
                        )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Both _ model1 model2 ->
                        field.view { config | label = field.label } model1
                            ++ (case field.submit model1 of
                                    Ok output ->
                                        let
                                            (Field field2) =
                                                f output
                                        in
                                        field2.view { config | label = field2.label } model2

                                    Err _ ->
                                        []
                               )

                    _ ->
                        []
        , subscriptions =
            \model ->
                case model of
                    Both _ model1 model2 ->
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
                    Both _ model1 model2 ->
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
                              , path = Location.pathFromModel model
                              , fail = True
                              }
                            ]
        , send = field.send
        , intercept = field.intercept
        , label = field.label
        , maybeAddress = field.maybeAddress
        }


{-| Provide a view function to display the [`Feedback`](#Feedback) generated 
when a [`Field`](#Field)'s `submit` function returns errors.
-}
showFeedback :
    (List Feedback -> H.Html (Msg msg))
    -> Field model msg address innerMsg output
    -> Field model msg address innerMsg output
showFeedback render (Field field) =
    Field
        { field
            | view =
                \config model ->
                    let
                        relevantFeedback =
                            List.filter (\f -> f.path == Location.pathFromModel model) config.feedback
                    in
                    field.view config model ++ [ render relevantFeedback ]
        }


{-| Begin defining a `choice` between multiple [`option`](#option)s.
-}
choice : Field model msg NoAddress Never output
choice =
    Field
        { init = \path maybeAddress -> ( OneOf (Location.new path maybeAddress) { selected = 0 } [], Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \_ -> Err []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeAddress = Nothing
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
    
    Yafl.choice
        |> Yafl.option 
            "This is the label for the radio button" 
            (Fields.fields.int 
                |> Yafl.label "This is a label for the `int` field"
            )
    

-}
option :
    String
    -> Field model msg address innerMsg output
    -> Field model msg NoAddress Never output
    -> Field model msg NoAddress Never output
option radioLabel (Field field) (Field choice_) =
    Field
        { init =
            \path _ ->
                case choice_.init path choice_.maybeAddress of
                    ( OneOf location selection options, choiceCmd ) ->
                        let
                            ( fieldModel, fieldCmd ) =
                                field.init (List.length options :: path) field.maybeAddress
                        in
                        ( OneOf location selection (( radioLabel, fieldModel ) :: options)
                        , Cmd.batch [ choiceCmd, fieldCmd ]
                        )

                    _ ->
                        field.init path field.maybeAddress
        , update =
            \msg model ->
                case model of
                    OneOf location selection ((( fieldLabel, fieldModel ) :: choiceLabelsAndModels) as options) ->
                        let
                            fallback =
                                let
                                    ( newFieldModel, fieldCmd ) =
                                        field.update msg fieldModel

                                    ( newChoiceModels, choiceCmd ) =
                                        choice_.update msg (OneOf location selection choiceLabelsAndModels)
                                in
                                case newChoiceModels of
                                    OneOf _ _ options2 ->
                                        ( OneOf location selection (( fieldLabel, newFieldModel ) :: options2)
                                        , Cmd.batch [ choiceCmd, fieldCmd ]
                                        )

                                    _ ->
                                        ( model, Cmd.none )
                        in
                        case msg of
                            OptionSelected locator ->
                                case List.Extra.find (\( _, optionModel ) -> Location.isLocated locator (Location.fromModel optionModel)) options of
                                    Just ( _, optionModel ) ->
                                        ( OneOf location
                                            { selected =
                                                Location.pathFromModel optionModel
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
                    OneOf location meta (( fieldLabel, fieldModel ) :: choiceModels) ->
                        let
                            radio idx lbl =
                                H.label [ HA.class "yafl-radio-option" ]
                                    [ H.input
                                        [ HA.type_ "radio"
                                        , HA.name config.label
                                        , HE.onClick (OptionSelected (ByPath (idx :: Location.toPath location)))
                                        , HA.checked (meta.selected == idx)
                                        ]
                                        []
                                    , H.text lbl
                                    ]

                            labels =
                                List.map Tuple.first (List.reverse choiceModels) ++ [ fieldLabel ]
                        in
                        H.fieldset [] (H.legend [] [ H.text config.label ] :: List.indexedMap radio labels)
                            :: (if meta.selected == List.length choiceModels then
                                    field.view { config | label = field.label } fieldModel

                                else
                                    choice_.view { config | label = choice_.label } (OneOf location meta choiceModels)
                                        |> List.drop 1
                               )

                    _ ->
                        [ H.text "error: not a OneOf" ]
        , subscriptions =
            \model ->
                case model of
                    OneOf location meta (( _, fieldModel ) :: options) ->
                        Sub.batch
                            [ choice_.subscriptions (OneOf location meta options)
                            , field.subscriptions fieldModel
                            ]

                    _ ->
                        Sub.none
        , submit =
            \model ->
                case model of
                    OneOf location meta (( _, fieldModel ) :: options) ->
                        if meta.selected == List.length options then
                            field.submit fieldModel

                        else
                            choice_.submit (OneOf location meta options)

                    _ ->
                        Err []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = choice_.label
        , maybeAddress = Nothing
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
            ({ blankModel : model
             , blankMsg : b
             , ctor :
                Field model msg NoAddress innerMsg value -> c
             }
             -> ( msg -> Maybe innerMsg, tailA )
             -> ( Maybe innerMsg -> b -> msg, tailB )
             -> ( model -> Maybe a2, tailC )
             -> ( Maybe a3 -> model -> model, tailD )
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
            ({ blankModel : model, blankMsg : b, ctor : c }
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
    (msg -> Maybe innerMsg)
    -> (Maybe innerMsg -> b -> msg)
    -> (model -> Maybe a)
    -> (Maybe a1 -> model -> model)
    ->
        { init : ( a1, Cmd innerMsg )
        , label : String
        , submit : a -> Result (List String) value
        , subscriptions : a -> Sub innerMsg
        , update : innerMsg -> a -> ( a1, Cmd innerMsg )
        , view : ViewConfig -> a -> List (H.Html innerMsg)
        }
    ->
        { blankModel : model
        , blankMsg : b
        , ctor : Field model msg NoAddress innerMsg value -> d
        }
    -> { blankModel : model, blankMsg : b, ctor : d }
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
                                        |> Result.mapError (\errs -> List.map (\err -> { message = err, fail = True, path = [] }) errs)
                                )
                            |> Maybe.withDefault (Err [ { message = "error in `applier` function", fail = True, path = [] } ])
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
    { init : ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , blankModel : model
    , view : ViewConfig -> model -> List (H.Html msg)
    , submit : model -> Result (List Feedback) value
    , subscriptions : model -> Sub msg
    , send : innerMsg -> msg
    , intercept : msg -> Maybe innerMsg
    , label : String
    }
    -> Field model msg NoAddress innerMsg value
wrapWithTrees args =
    Field
        { init =
            \path maybeAddress ->
                let
                    location =
                        Location.new path maybeAddress
                in
                args.init
                    |> Tuple.mapBoth
                        (\model -> Value location model)
                        (\cmd -> Cmd.map (ValueChanged (Location.toLocator location)) cmd)
        , update =
            \msg model ->
                internalUpdate args.update msg model
        , view =
            \config model ->
                let
                    location =
                        Location.fromModel model

                    path =
                        Location.toPath location

                    relevantFeedback =
                        List.filter (\f -> f.path == path) config.feedback

                    ( model_, mapper ) =
                        case model of
                            Value _ model__ ->
                                ( model__, ValueChanged (Location.toLocator location) )

                            _ ->
                                ( args.blankModel, always Noop )
                in
                args.view { config | feedback = relevantFeedback } model_
                    |> List.map (H.map mapper)
        , submit =
            \model ->
                case model of
                    Value location model_ ->
                        args.submit model_
                            |> Result.mapError (\errs -> List.map (\err -> { err | path = Location.toPath location }) errs)

                    _ ->
                        Err []
        , subscriptions =
            \model ->
                case model of
                    Value location model_ ->
                        args.subscriptions model_
                            |> Sub.map (ValueChanged (Location.toLocator location))

                    _ ->
                        Sub.none
        , send =
            \maybeAddress msg ->
                case maybeAddress of
                    Nothing ->
                        Noop

                    Just address_ ->
                        ValueChanged (ByAddress address_) (args.send msg)
        , intercept =
            \maybeAddress msg ->
                case ( maybeAddress, msg ) of
                    ( Just address_, ValueChanged (ByAddress msgAddress) msgTuple ) ->
                        if msgAddress == address_ then
                            args.intercept msgTuple

                        else
                            Nothing

                    _ ->
                        Nothing
        , label = args.label
        , maybeAddress = Nothing
        }


internalUpdate :
    (msg -> model -> ( model, Cmd a ))
    -> Msg msg
    -> Model model
    -> ( Model model, Cmd (Msg a) )
internalUpdate update_ msg model =
    case model of
        Value location innerModel ->
            case msg of
                ValueChanged locator innerMsg ->
                    if Location.isLocated locator location then
                        let
                            ( newModel, cmd ) =
                                update_ innerMsg innerModel
                        in
                        ( Value location newModel
                        , Cmd.map (ValueChanged (Location.toLocator location)) cmd
                        )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Both location model1 model2 ->
            let
                ( newModel1, cmd1 ) =
                    internalUpdate update_ msg model1

                ( newModel2, cmd2 ) =
                    internalUpdate update_ msg model2
            in
            ( Both location newModel1 newModel2
            , Cmd.batch [ cmd1, cmd2 ]
            )

        OneOf location selection options ->
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
                    ( OneOf location selection (List.Extra.zip labels newModels)
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
                                        Location.fromModel optionModel
                                in
                                if Location.isLocated locator optionLocation then
                                    optionLocation
                                        |> Location.toPath
                                        |> List.head

                                else
                                    Nothing
                            )
                            options
                    of
                        Just selected ->
                            ( OneOf location { selected = selected } options
                            , Cmd.none
                            )

                        Nothing ->
                            fallback

                _ ->
                    fallback

        Empty _ ->
            ( model, Cmd.none )


locateOneOf : Locator -> Model model -> ( Model model, Cmd msg )
locateOneOf locator model =
    case model of
        OneOf location selection options ->
            case
                List.Extra.findMap
                    (\( _, optionModel ) ->
                        if Location.isLocated locator (Location.fromModel optionModel) then
                            Location.pathFromModel optionModel
                                |> List.head

                        else
                            Nothing
                    )
                    options
            of
                Just selected ->
                    ( OneOf location
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
                                |> List.map (locateOneOf locator)
                                |> List.unzip
                    in
                    ( OneOf location selection (List.Extra.zip labels newModels)
                    , Cmd.batch cmds
                    )

        Value _ _ ->
            ( model, Cmd.none )

        Both location model1 model2 ->
            let
                ( newModel1, cmd1 ) =
                    locateOneOf locator model1

                ( newModel2, cmd2 ) =
                    locateOneOf locator model2
            in
            ( Both location newModel1 newModel2
            , Cmd.batch
                [ cmd1, cmd2 ]
            )

        Empty _ ->
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
