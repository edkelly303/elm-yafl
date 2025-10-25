module Yafl exposing
    ( Widget
    , Field, defineFields, addWidget, addWidgetWithConfig, endFields
    , Model, Msg, init, update, view, ViewConfig, Feedback, subscriptions, submit
    , succeed, fail, failAt
    , map, andThen
    , map2, andMap
    , choice, option
    , label
    , validate, validateAt
    , HasId, NoId, id, intercept, send, select
    , updateField, andUpdateField, selectField, andSelectField
    , studio, toDOT
    )

{-| This library helps you build user input forms in Elm by creating and
composing self-contained [`Widget`](#Widget)s.


## Table of contents


### [Creating Widgets](#creating-widgets)

[`Widget`](#Widget)


### [Turning Widgets into Fields](#turning-widgets-into-fields)

[`Field`](#Field), [`defineFields`](#defineFields), [`addWidget`](#addWidget), [`addWidgetWithConfig`](#addWidgetWithConfig), [`endFields`](#endFields)


### [Turning Fields into forms](#turning-fields-into-forms)

[`Model`](#Model), [`Msg`](#Msg), [`init`](#init), [`update`](#update), [`view`](#view), [`ViewConfig`](#ViewConfig), [`Feedback`](#Feedback), [`subscriptions`](#subscriptions), [`submit`](#submit)


### [Combining Fields](#combining-fields)

[`succeed`](#succeed), [`fail`](#fail), [`failAt`](#failAt), [`map`](#map), [`andThen`](#andThen), [`map2`](#map2), [`andMap`](#andMap), [`choice`](#choice), [`option`](#option)


### [Customizing Fields](#customizing-fields)

[`label`](#label)


### [Validating fields](#validating-fields)

[`validate`](#validate), [`validateAt`](#validateAt)


### [Communicating between Fields](#communicating-between-fields)

[`HasId`](#HasId), [`NoId`](#NoId), [`id`](#id), [`intercept`](#intercept), [`send`](#send), [`select`](#select)


### [Updating Fields synchronously](#updating-fields-synchronously)

[`updateField`](#updateField), [`andUpdateField`](#andUpdateField), [`selectField`](#selectField), [`andSelectField`](#andSelectField)


### [Debugging](#debugging)

[`studio`](#studio), [`toDOT`](#toDOT)


# Creating Widgets

[_Back to top_](#table-of-contents)

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

[_Back to top_](#table-of-contents)

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

@docs Field, defineFields, addWidget, addWidgetWithConfig, endFields


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

[_Back to top_](#table-of-contents)


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

[_Back to top_](#table-of-contents)

@docs label


# Validating fields

[_Back to top_](#table-of-contents)

@docs validate, validateAt


# Communicating between Fields

[_Back to top_](#table-of-contents)

@docs HasId, NoId, id, intercept, send, select


# Updating Fields synchronously

[_Back to top_](#table-of-contents)

@docs updateField, andUpdateField, selectField, andSelectField


# Debugging

[_Back to top_](#table-of-contents)

@docs studio, toDOT

-}

import Browser
import Dict
import Html as H
import Html.Attributes as HA
import Html.Events as HE
import List.Extra
import NestedTuple as NT
import Regex
import Task
import Yafl.Internal
    exposing
        ( EmptyType(..)
        , Field(..)
        , InnerWidget
        , InternalFeedback
        , Loader(..)
        , LoaderNode(..)
        , Location(..)
        , Locator(..)
        , MaybeId
        , Model(..)
        , Msg(..)
        , Node(..)
        , Path
        , ProductType(..)
        , ViewConfig
        )


type alias Widget config model msg output =
    Yafl.Internal.Widget config model msg output


type alias Field formModel formMsg id widgetMsg input output =
    Yafl.Internal.Field formModel formMsg id widgetMsg input output


type alias Model formModel output =
    Yafl.Internal.Model formModel output


type alias Msg formMsg =
    Yafl.Internal.Msg formMsg


type alias HasId =
    Yafl.Internal.HasId


type alias NoId =
    Yafl.Internal.NoId


type alias ViewConfig =
    Yafl.Internal.ViewConfig


type alias Feedback =
    Yafl.Internal.Feedback



{-
   d888888b d8b   db d888888b d888888b
     `88'   888o  88   `88'   `~~88~~'
      88    88V8o 88    88       88
      88    88 V8o88    88       88
     .88.   88  V888   .88.      88
   Y888888P VP   V8P Y888888P    YP


-}


{-| Initialize your form

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    fields.bool
        |> Yafl.init

    --: ( Yafl.Model FormModel Bool, Cmd (Yafl.Msg FormMsg) )

-}
init : Field formModel formMsg id widgetMsg input output -> ( Model formModel output, Cmd (Msg formMsg) )
init (Field field) =
    field.init [ 0 ] field.maybeId
        |> Tuple.mapFirst Model



{-
   db    db d8888b. d8888b.  .d8b.  d888888b d88888b
   88    88 88  `8D 88  `8D d8' `8b `~~88~~' 88'
   88    88 88oodD' 88   88 88ooo88    88    88ooooo
   88    88 88~~~   88   88 88~~~88    88    88~~~~~
   88b  d88 88      88  .8D 88   88    88    88.
   ~Y8888P' 88      Y8888D' YP   YP    YP    Y88888P


-}


{-| Update your form by supplying a `Msg` and `Model`
-}
update : Field formModel formMsg id widgetMsg input output -> Msg formMsg -> Model formModel output -> ( Model formModel output, Cmd (Msg formMsg) )
update (Field field) msg (Model node) =
    field.update msg node
        |> Tuple.mapFirst Model



{-
   db    db d888888b d88888b db   d8b   db
   88    88   `88'   88'     88   I8I   88
   Y8    8P    88    88ooooo 88   I8I   88
   `8b  d8'    88    88~~~~~ Y8   I8I   88
    `8bd8'    .88.   88.     `8b d8'8b d8'
      YP    Y888888P Y88888P  `8b8' `8d8'


-}


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
view : Field formModel formMsg id widgetMsg input output -> Model formModel output -> List (H.Html (Msg formMsg))
view (Field field) (Model model) =
    let
        feedback =
            case field.submit field.checks model of
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



{-
   .d8888. db    db d8888b. .d8888.  .o88b. d8888b. d888888b d8888b. d888888b d888888b  .d88b.  d8b   db .d8888.
   88'  YP 88    88 88  `8D 88'  YP d8P  Y8 88  `8D   `88'   88  `8D `~~88~~'   `88'   .8P  Y8. 888o  88 88'  YP
   `8bo.   88    88 88oooY' `8bo.   8P      88oobY'    88    88oodD'    88       88    88    88 88V8o 88 `8bo.
     `Y8b. 88    88 88~~~b.   `Y8b. 8b      88`8b      88    88~~~      88       88    88    88 88 V8o88   `Y8b.
   db   8D 88b  d88 88   8D db   8D Y8b  d8 88 `88.   .88.   88         88      .88.   `8b  d8' 88  V888 db   8D
   `8888Y' ~Y8888P' Y8888P' `8888Y'  `Y88P' 88   YD Y888888P 88         YP    Y888888P  `Y88P'  VP   V8P `8888Y'


-}


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
subscriptions : Field formModel formMsg id widgetMsg input output -> Model formModel output -> Sub (Msg formMsg)
subscriptions (Field field) (Model model) =
    field.subscriptions model



{-
   .d8888. db    db d8888b. .88b  d88. d888888b d888888b
   88'  YP 88    88 88  `8D 88'YbdP`88   `88'   `~~88~~'
   `8bo.   88    88 88oooY' 88  88  88    88       88
     `Y8b. 88    88 88~~~b. 88  88  88    88       88
   db   8D 88b  d88 88   8D 88  88  88   .88.      88
   `8888Y' ~Y8888P' Y8888P' YP  YP  YP Y888888P    YP


-}


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
submit : Field formModel formMsg id widgetMsg input output -> Model formModel output -> Result (List ( String, String )) output
submit (Field field) (Model model) =
    field.submit field.checks model
        |> Result.mapError
            (List.map
                (\{ message, locator } ->
                    ( locatorToString locator
                    , message
                    )
                )
            )



{-
   db       .d8b.  d8888b. d88888b db
   88      d8' `8b 88  `8D 88'     88
   88      88ooo88 88oooY' 88ooooo 88
   88      88~~~88 88~~~b. 88~~~~~ 88
   88booo. 88   88 88   8D 88.     88booo.
   Y88888P YP   YP Y8888P' Y88888P Y88888P


-}


{-| Add a label to a Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    nameField =
        fields.string
            |> Yafl.label "What is your name?"

    nameField

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String

-}
label : String -> Field formModel formMsg id widgetMsg input output -> Field formModel formMsg id widgetMsg input output
label label_ (Field field) =
    Field { field | label = label_ }



{-
   db    db  .d8b.  db      d888888b d8888b.  .d8b.  d888888b d88888b
   88    88 d8' `8b 88        `88'   88  `8D d8' `8b `~~88~~' 88'
   Y8    8P 88ooo88 88         88    88   88 88ooo88    88    88ooooo
   `8b  d8' 88~~~88 88         88    88   88 88~~~88    88    88~~~~~
    `8bd8'  88   88 88booo.   .88.   88  .8D 88   88    88    88.
      YP    YP   YP Y88888P Y888888P Y8888D' YP   YP    YP    Y88888P


-}


{-| Validate a field and specify an error message if validation fails.

    import Yafl

    form =
        Yafl.succeed 0
            |> Yafl.validate
                (\int ->
                    if int > 0 then
                        Nothing
                    else
                        Just
                            ("Must be greater than 0, but the value is "
                                ++ String.fromInt int
                            )
                )

    form
        |> Yafl.init
        |> Tuple.first
        |> Yafl.submit form

    --> Err [ ( "0", "Must be greater than 0, but the value is 0" ) ]

-}
validate :
    (output -> Maybe String)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
validate check (Field field) =
    Field { field | checks = field.checks ++ [ ( Nothing, check ) ] }



{-
   db    db  .d8b.  db      d888888b d8888b.  .d8b.  d888888b d88888b  .d8b.  d888888b
   88    88 d8' `8b 88        `88'   88  `8D d8' `8b `~~88~~' 88'     d8' `8b `~~88~~'
   Y8    8P 88ooo88 88         88    88   88 88ooo88    88    88ooooo 88ooo88    88
   `8b  d8' 88~~~88 88         88    88   88 88~~~88    88    88~~~~~ 88~~~88    88
    `8bd8'  88   88 88booo.   .88.   88  .8D 88   88    88    88.     88   88    88
      YP    YP   YP Y88888P Y888888P Y8888D' YP   YP    YP    Y88888P YP   YP    YP


-}


{-| Validate a field and specify an error to display on a _different_ field.
This is useful when you are doing validation that involves multiple fields, but
you only want to display an error on one field.

    import Yafl
    import Examples exposing (fields)

    passwordField =
        fields.string
            |> Yafl.id "password"

    confirmField =
        fields.string
            |> Yafl.id "confirm"

    form =
        Yafl.succeed
            (\password confirm -> { password = password, confirm = confirm })
            |> Yafl.andMap passwordField
            |> Yafl.andMap confirmField
            |> Yafl.validateAt confirmField
                (\{password, confirm} ->
                    if password == confirm then
                        Nothing
                    else
                        Just "Passwords do not match"
                )

    form
        |> Yafl.init
        |> Yafl.andUpdateField form passwordField "password123"
        |> Yafl.andUpdateField form confirmField "password124"
        |> Tuple.first
        |> Yafl.submit form

    --> Err [ ( "confirm", "Passwords do not match" ) ]

-}
validateAt :
    Field formModel formMsg HasId widgetMsg2 input2 output2
    -> (output -> Maybe String)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
validateAt (Field target) check (Field field) =
    Field { field | checks = field.checks ++ [ ( target.maybeId, check ) ] }



{-
   d888888b d8888b.
     `88'   88  `8D
      88    88   88
      88    88   88
     .88.   88  .8D
   Y888888P Y8888D'


-}


{-| Add a unique identifier to a [`Field`](#Field), which can be used to send and intercept
messages to that Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myField =
        fields.string

    myField

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String

    myFieldWithId =
        myField
            |> Yafl.id "any-string-as-long-as-it's-unique"

    myFieldWithId

    --: Yafl.Field FormModel FormMsg Yafl.HasId String String

    Yafl.send myFieldWithId "Hello!"

    --: Cmd (Yafl.Msg FormMsg)

This identifier is also used as the `id` string in [`ViewConfig`](#ViewConfig),
which is passed into the view when the Field is rendered. When defining a
Widget, you can use the `id` field of the `ViewConfig` to set the
`Html.Attributes.id` of the HTML input.

-}
id :
    String
    -> Field formModel formMsg NoId widgetMsg input output
    -> Field formModel formMsg HasId widgetMsg input output
id sendId_ (Field field) =
    Field { field | maybeId = Just sendId_ }



{-
   .d8888. d88888b db      d88888b  .o88b. d888888b
   88'  YP 88'     88      88'     d8P  Y8 `~~88~~'
   `8bo.   88ooooo 88      88ooooo 8P         88
     `Y8b. 88~~~~~ 88      88~~~~~ 8b         88
   db   8D 88.     88booo. 88.     Y8b  d8    88
   `8888Y' Y88888P Y88888P Y88888P  `Y88P'    YP


-}


{-| Create a `Cmd` that will select a specific [`option`](#option) in a
[`choice`](#choice) Field.

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
select : Field formModel formMsg HasId widgetMsg input output -> Cmd (Msg msg)
select (Field field) =
    case field.maybeId of
        Just id_ ->
            Task.perform identity (Task.succeed (OptionSelected (ById id_)))

        Nothing ->
            Cmd.none



{-
   .d8888. d88888b d8b   db d8888b.
   88'  YP 88'     888o  88 88  `8D
   `8bo.   88ooooo 88V8o 88 88   88
     `Y8b. 88~~~~~ 88 V8o88 88   88
   db   8D 88.     88  V888 88  .8D
   `8888Y' Y88888P VP   V8P Y8888D'


-}


{-| Create a `Cmd` that will send a message to a specific [`option`](#option) in
a [`choice`](#choice) Field.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myFieldWithId =
        fields.string
            |> Yafl.id "any-string-as-long-as-it's-unique"

    Yafl.send myFieldWithId "Hello!"

    --: Cmd (Yafl.Msg FormMsg)

-}
send : Field formModel formMsg HasId widgetMsg input output -> widgetMsg -> Cmd (Msg formMsg)
send (Field field) msg =
    Task.perform identity (Task.succeed (field.send field.maybeId msg))



{-
   d888888b d8b   db d888888b d88888b d8888b.  .o88b. d88888b d8888b. d888888b
     `88'   888o  88 `~~88~~' 88'     88  `8D d8P  Y8 88'     88  `8D `~~88~~'
      88    88V8o 88    88    88ooooo 88oobY' 8P      88ooooo 88oodD'    88
      88    88 V8o88    88    88~~~~~ 88`8b   8b      88~~~~~ 88~~~      88
     .88.   88  V888    88    88.     88 `88. Y8b  d8 88.     88         88
   Y888888P VP   V8P    YP    Y88888P 88   YD  `Y88P' Y88888P 88         YP


-}


{-| Intercept the top-level `Msg` sent to your form, and if it contains a message sent to the specified field, return that message.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    myFieldWithId =
        fields.string
            |> Yafl.id "any-string-as-long-as-it's-unique"

    Yafl.intercept myFieldWithId

    --: Yafl.Msg FormMsg -> Maybe String

-}
intercept : Field formModel formMsg HasId widgetMsg input output -> Msg formMsg -> Maybe widgetMsg
intercept (Field field) =
    field.intercept field.maybeId



{-
   db    db d8888b. d8888b.  .d8b.  d888888b d88888b d88888b d888888b d88888b db      d8888b.
   88    88 88  `8D 88  `8D d8' `8b `~~88~~' 88'     88'       `88'   88'     88      88  `8D
   88    88 88oodD' 88   88 88ooo88    88    88ooooo 88ooo      88    88ooooo 88      88   88
   88    88 88~~~   88   88 88~~~88    88    88~~~~~ 88~~~      88    88~~~~~ 88      88   88
   88b  d88 88      88  .8D 88   88    88    88.     88        .88.   88.     88booo. 88  .8D
   ~Y8888P' 88      Y8888D' YP   YP    YP    Y88888P YP      Y888888P Y88888P Y88888P Y8888D'


-}


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
            |> Yafl.updateField fooField firstField "Hello!"
            |> Tuple.first

    Yafl.submit fooField updatedModel

    --> Ok (Foo "Hello!" "")

-}
updateField :
    Field formModel formMsg id anyMsg formInput formOutput
    -> Field formModel formMsg HasId widgetMsg widgetInput widgetOutput
    -> widgetMsg
    -> Model formModel formOutput
    -> ( Model formModel formOutput, Cmd (Msg formMsg) )
updateField (Field form) (Field field) widgetMsg (Model model) =
    form.update (field.send field.maybeId widgetMsg) model
        |> Tuple.mapFirst Model



{-
    .d8b.  d8b   db d8888b. db    db d8888b. d8888b.  .d8b.  d888888b d88888b d88888b d888888b d88888b db      d8888b.
   d8' `8b 888o  88 88  `8D 88    88 88  `8D 88  `8D d8' `8b `~~88~~' 88'     88'       `88'   88'     88      88  `8D
   88ooo88 88V8o 88 88   88 88    88 88oodD' 88   88 88ooo88    88    88ooooo 88ooo      88    88ooooo 88      88   88
   88~~~88 88 V8o88 88   88 88    88 88~~~   88   88 88~~~88    88    88~~~~~ 88~~~      88    88~~~~~ 88      88   88
   88   88 88  V888 88  .8D 88b  d88 88      88  .8D 88   88    88    88.     88        .88.   88.     88booo. 88  .8D
   YP   YP VP   V8P Y8888D' ~Y8888P' 88      Y8888D' YP   YP    YP    Y88888P YP      Y888888P Y88888P Y88888P Y8888D'


-}


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
            |> Yafl.andUpdateField fooField firstField "Hello"
            |> Yafl.andUpdateField fooField secondField "World"
            |> Tuple.first

    Yafl.submit fooField updatedModel

    --> Ok (Foo "Hello" "World")

-}
andUpdateField :
    Field formModel formMsg id anyMsg formInput formOutput
    -> Field formModel formMsg HasId widgetMsg widgetInput widgetOutput
    -> widgetMsg
    -> ( Model formModel formOutput, Cmd (Msg formMsg) )
    -> ( Model formModel formOutput, Cmd (Msg formMsg) )
andUpdateField form field widgetMsg ( model, cmd1 ) =
    updateField form field widgetMsg model
        |> Tuple.mapSecond (\cmd2 -> Cmd.batch [ cmd1, cmd2 ])



{-
   .d8888. d88888b db      d88888b  .o88b. d888888b d88888b d888888b d88888b db      d8888b.
   88'  YP 88'     88      88'     d8P  Y8 `~~88~~' 88'       `88'   88'     88      88  `8D
   `8bo.   88ooooo 88      88ooooo 8P         88    88ooo      88    88ooooo 88      88   88
     `Y8b. 88~~~~~ 88      88~~~~~ 8b         88    88~~~      88    88~~~~~ 88      88   88
   db   8D 88.     88booo. 88.     Y8b  d8    88    88        .88.   88.     88booo. 88  .8D
   `8888Y' Y88888P Y88888P Y88888P  `Y88P'    YP    YP      Y888888P Y88888P Y88888P Y8888D'


-}


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
        |> Yafl.selectField myChoiceField myFieldWithId
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Ok "Hurrah!"

-}
selectField :
    Field formModel formMsg id anyMsg formInput formOutput
    -> Field formModel formMsg HasId widgetMsg widgetInput widgetOutput
    -> Model formModel formOutput
    -> ( Model formModel formOutput, Cmd (Msg formMsg) )
selectField (Field form) (Field field) (Model model) =
    case field.maybeId of
        Just id_ ->
            let
                msg =
                    OptionSelected (ById id_)
            in
            form.update msg model
                |> Tuple.mapFirst Model

        Nothing ->
            ( Model model, Cmd.none )



{-
    .d8b.  d8b   db d8888b. .d8888. d88888b db      d88888b  .o88b. d888888b d88888b d888888b d88888b db      d8888b.
   d8' `8b 888o  88 88  `8D 88'  YP 88'     88      88'     d8P  Y8 `~~88~~' 88'       `88'   88'     88      88  `8D
   88ooo88 88V8o 88 88   88 `8bo.   88ooooo 88      88ooooo 8P         88    88ooo      88    88ooooo 88      88   88
   88~~~88 88 V8o88 88   88   `Y8b. 88~~~~~ 88      88~~~~~ 8b         88    88~~~      88    88~~~~~ 88      88   88
   88   88 88  V888 88  .8D db   8D 88.     88booo. 88.     Y8b  d8    88    88        .88.   88.     88booo. 88  .8D
   YP   YP VP   V8P Y8888D' `8888Y' Y88888P Y88888P Y88888P  `Y88P'    YP    YP      Y888888P Y88888P Y88888P Y8888D'


-}


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
        |> Yafl.andSelectField myChoiceField myFieldWithId
        |> Tuple.first
        |> Yafl.submit myChoiceField

    --> Ok "Hurrah!"

-}
andSelectField :
    Field formModel formMsg id anyMsg formInput formOutput
    -> Field formModel formMsg HasId widgetMsg widgetInput widgetOutput
    -> ( Model formModel formOutput, Cmd (Msg formMsg) )
    -> ( Model formModel formOutput, Cmd (Msg formMsg) )
andSelectField form field ( model, cmd1 ) =
    selectField form field model
        |> Tuple.mapSecond (\cmd2 -> Cmd.batch [ cmd1, cmd2 ])



{-
   .d8888. db    db  .o88b.  .o88b. d88888b d88888b d8888b.
   88'  YP 88    88 d8P  Y8 d8P  Y8 88'     88'     88  `8D
   `8bo.   88    88 8P      8P      88ooooo 88ooooo 88   88
     `Y8b. 88    88 8b      8b      88~~~~~ 88~~~~~ 88   88
   db   8D 88b  d88 Y8b  d8 Y8b  d8 88.     88.     88  .8D
   `8888Y' ~Y8888P'  `Y88P'  `Y88P' Y88888P Y88888P Y8888D'


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
succeed : output -> Field formModel formMsg id widgetMsg input output
succeed output =
    Field
        { init = \path maybeId -> ( Empty Succeed (newLocation path maybeId), Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit = \checks model -> runChecks checks model output
        , checks = []
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
   d88888b  .d8b.  d888888b db
   88'     d8' `8b   `88'   88
   88ooo   88ooo88    88    88
   88~~~   88~~~88    88    88
   88      88   88   .88.   88booo.
   YP      YP   YP Y888888P Y88888P


-}


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
fail : String -> Field formModel formMsg id widgetMsg input output
fail e =
    Field
        { init = \path maybeId -> ( Empty Fail (newLocation path maybeId), Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view =
            \{ feedback } model ->
                case List.filter (\f -> isLocated f.locator (locationFromModel model)) feedback of
                    [] ->
                        []

                    filtered ->
                        [ H.ul []
                            (List.map
                                (\f -> H.li [] [ H.text f.message ])
                                filtered
                            )
                        ]
                            |> Debug.log "We really need to give the user a way to define how they want errors to be rendered"
        , subscriptions = \_ -> Sub.none
        , submit =
            \_ model ->
                Err
                    [ { message = e
                      , fail = True
                      , locator = locationFromModel model |> locationToLocator
                      }
                    ]
        , checks = []
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
   d88888b  .d8b.  d888888b db       .d8b.  d888888b
   88'     d8' `8b   `88'   88      d8' `8b `~~88~~'
   88ooo   88ooo88    88    88      88ooo88    88
   88~~~   88~~~88    88    88      88~~~88    88
   88      88   88   .88.   88booo. 88   88    88
   YP      YP   YP Y888888P Y88888P YP   YP    YP


-}


{-| Like `fail`, except it will display the error message on a _different_
Field. This can be useful in multi-field validation, when you have an error that
results from a combination of several fields, but you only want to display the
error message on one specific field.
-}
failAt :
    Field formModel formMsg HasId widgetMsg1 input1 output1
    -> String
    -> Field formModel formMsg address2 widgetMsg2 input2 output2
failAt (Field failField) e =
    Field
        { init = \path maybeId -> ( Empty Fail (newLocation path maybeId), Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view =
            \{ feedback } model ->
                case List.filter (\f -> isLocated f.locator (locationFromModel model)) feedback of
                    [] ->
                        []

                    filtered ->
                        [ H.ul []
                            (List.map
                                (\f -> H.li [] [ H.text f.message ])
                                filtered
                            )
                        ]
                            |> Debug.log "We really need to give the user a way to define how they want errors to be rendered"
        , subscriptions = \_ -> Sub.none
        , submit =
            \_ model ->
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
        , checks = []
        , send = \_ _ -> Noop
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
   .88b  d88.  .d8b.  d8888b.
   88'YbdP`88 d8' `8b 88  `8D
   88  88  88 88ooo88 88oodD'
   88  88  88 88~~~88 88~~~
   88  88  88 88   88 88
   YP  YP  YP YP   YP 88


-}


{-| Convert the output of a [`Field`](#Field) from one type to another.

A common use case for this function is to create `Field`s that produce custom
type variants.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    -- Example 1: Creating a custom type variant

    type MyCustomType
        = Foo String

    fooField =
        Yafl.map Foo (fields.string)

    fooField
        |> Yafl.init
        |> Tuple.first
        |> Yafl.submit fooField

    --> Ok (Foo "")

-}
map :
    (output -> output2)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output2
map f (Field field) =
    Field
        { init = field.init
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , submit =
            \checks model ->
                field.submit field.checks model
                    |> Result.map f
                    |> Result.andThen (runChecks checks model)
        , checks = []
        , send = field.send
        , intercept = field.intercept
        , label = field.label
        , maybeId = field.maybeId
        }



{-
   .88b  d88.  .d8b.  d8888b. .d888b.
   88'YbdP`88 d8' `8b 88  `8D VP  `8D
   88  88  88 88ooo88 88oodD'    odD'
   88  88  88 88~~~88 88~~~    .88'
   88  88  88 88   88 88      j88.
   YP  YP  YP YP   YP 88      888888D


-}


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
            (fields.string)
            (fields.string)

    model =
        Yafl.init form
            |> Tuple.first

    Yafl.submit form model

    --> Ok ( "", "" )

-}
map2 :
    (output1 -> output2 -> output3)
    -> Field formModel formMsg address1 widgetMsg1 input1 output1
    -> Field formModel formMsg address2 widgetMsg2 input2 output2
    -> Field formModel formMsg NoId Never input3 output3
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
            \checks model ->
                case model of
                    Product _ _ model1 model2 ->
                        case
                            ( field1.submit field1.checks model1
                            , field2.submit field2.checks model2
                            )
                        of
                            ( Ok output1, Ok output2 ) ->
                                f output1 output2
                                    |> runChecks checks model

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
        , checks = []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
    .d8b.  d8b   db d8888b. .88b  d88.  .d8b.  d8888b.
   d8' `8b 888o  88 88  `8D 88'YbdP`88 d8' `8b 88  `8D
   88ooo88 88V8o 88 88   88 88  88  88 88ooo88 88oodD'
   88~~~88 88 V8o88 88   88 88  88  88 88~~~88 88~~~
   88   88 88  V888 88  .8D 88  88  88 88   88 88
   YP   YP VP   V8P Y8888D' YP  YP  YP YP   YP 88


-}


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
    Field formModel formMsg address1 widgetMsg1 input1 output1
    -> Field formModel formMsg address2 widgetMsg2 input2 (output1 -> output2)
    -> Field formModel formMsg NoId Never input2 output2
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
                            field2.view { config | label = field2.label, id = locationFromModel model2 |> locationToString } model2
                                ++ field1.view { config | label = field1.label, id = locationFromModel model1 |> locationToString } model1

                        _ ->
                            []
        }



{-
    .d8b.  d8b   db d8888b. d888888b db   db d88888b d8b   db
   d8' `8b 888o  88 88  `8D `~~88~~' 88   88 88'     888o  88
   88ooo88 88V8o 88 88   88    88    88ooo88 88ooooo 88V8o 88
   88~~~88 88 V8o88 88   88    88    88~~~88 88~~~~~ 88 V8o88
   88   88 88  V888 88  .8D    88    88   88 88.     88  V888
   YP   YP VP   V8P Y8888D'    YP    YP   YP Y88888P VP   V8P


-}


{-| Check the result of submitting a [`Field`](#Field), and optionally display
another `Field`. This can be useful if you want to ask the user for more
information, or to convert an existing [`Widget`](#Widget) to return a different
output type.

(You _can_ also use it for validating a field's output, but it will probably be
better to use [`validate`](#validate) or [`validateAt`](#validateAt) instead.)

The [`succeed`](#succeed) and [`fail`](#fail) functions are often useful in
combination with this function.

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    -- Example 1: Asking the user for additional information

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

    -- Example 2: Repurposing an existing widget to return a different type

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

    -- Example 3: Validating a field's output

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

-}
andThen :
    (output -> Field formModel formMsg id2 widgetMsg2 input2 output2)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input2 output2
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
                        case field.submit field.checks model1 of
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
                case model of
                    Product AndThen location model1 model2 ->
                        let
                            ( newModel1, cmd1 ) =
                                field.update msg model1

                            ( newModel2, cmd2 ) =
                                case field.submit field.checks newModel1 of
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

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Product _ _ model1 model2 ->
                        field.view { config | id = locationFromModel model1 |> locationToString } model1
                            ++ (case field.submit field.checks model1 of
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
                            , case field.submit field.checks model1 of
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
            \_ model ->
                case model of
                    Product _ _ model1 model2 ->
                        field.submit field.checks model1
                            |> Result.andThen
                                (\output ->
                                    let
                                        (Field field2) =
                                            f output
                                    in
                                    field2.submit field2.checks model2
                                )

                    _ ->
                        Err
                            [ { message = "Fatal error, expecting a `Product` node"
                              , locator = locatorFromModel model
                              , fail = True
                              }
                            ]
        , checks = []
        , send = field.send
        , intercept = field.intercept
        , label = field.label
        , maybeId = field.maybeId
        }



{-
    .o88b. db   db  .d88b.  d888888b  .o88b. d88888b
   d8P  Y8 88   88 .8P  Y8.   `88'   d8P  Y8 88'
   8P      88ooo88 88    88    88    8P      88ooooo
   8b      88~~~88 88    88    88    8b      88~~~~~
   Y8b  d8 88   88 `8b  d8'   .88.   Y8b  d8 88.
    `Y88P' YP   YP  `Y88P'  Y888888P  `Y88P' Y88888P


-}


{-| Begin defining a `choice` between multiple [`option`](#option)s.
-}
choice : Field formModel formMsg NoId Never input output
choice =
    Field
        { init = \path maybeId -> ( Sum (newLocation path maybeId) { selected = 0 } [], Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> []
        , subscriptions = \_ -> Sub.none
        , submit =
            \_ model ->
                Err
                    [ { message = "empty choice"
                      , fail = True
                      , locator = locatorFromModel model
                      }
                    ]
        , checks = []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = ""
        , maybeId = Nothing
        }



{-
    .d88b.  d8888b. d888888b d888888b  .d88b.  d8b   db
   .8P  Y8. 88  `8D `~~88~~'   `88'   .8P  Y8. 888o  88
   88    88 88oodD'    88       88    88    88 88V8o 88
   88    88 88~~~      88       88    88    88 88 V8o88
   `8b  d8' 88         88      .88.   `8b  d8' 88  V888
    `Y88P'  88         YP    Y888888P  `Y88P'  VP   V8P


-}


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
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id2 Never input output
    -> Field formModel formMsg id2 Never input output
option thisOptionLabel (Field thisOptionField) (Field previousOptionFields) =
    Field
        { init =
            \path _ ->
                case previousOptionFields.init path previousOptionFields.maybeId of
                    ( Sum location selection previousOptions, previousOptionsCmd ) ->
                        let
                            ( thisOptionModel, thisOptionCmd ) =
                                thisOptionField.init (List.length previousOptions :: path) thisOptionField.maybeId
                        in
                        ( Sum location selection (( thisOptionLabel, thisOptionModel ) :: previousOptions)
                        , Cmd.batch [ previousOptionsCmd, thisOptionCmd ]
                        )

                    _ ->
                        thisOptionField.init path thisOptionField.maybeId
        , update =
            \msg model ->
                case model of
                    Sum location selection ((( _, thisOptionModel ) :: previousOptionLabelsAndModels) as options) ->
                        let
                            fallback =
                                let
                                    ( newThisOptionModel, thisOptionCmd ) =
                                        thisOptionField.update msg thisOptionModel

                                    ( newPreviousOptionModels, previousOptionsCmd ) =
                                        previousOptionFields.update msg (Sum location selection previousOptionLabelsAndModels)
                                in
                                case newPreviousOptionModels of
                                    Sum _ _ newPreviousOptionLabelsAndModels ->
                                        ( Sum location selection (( thisOptionLabel, newThisOptionModel ) :: newPreviousOptionLabelsAndModels)
                                        , Cmd.batch [ previousOptionsCmd, thisOptionCmd ]
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
                    Sum location meta (( _, thisOptionModel ) :: previousOptionLabelsAndModels) ->
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

                            previousLabels =
                                List.map Tuple.first previousOptionLabelsAndModels

                            labels =
                                List.reverse (thisOptionLabel :: previousLabels)

                            viewOptionSelector =
                                H.fieldset [ HA.id (locationToString location) ]
                                    (H.legend [] [ H.text config.label ] :: List.indexedMap radio labels)

                            viewSelectedOption =
                                if meta.selected == List.length previousOptionLabelsAndModels then
                                    thisOptionField.view
                                        { config
                                            | label = thisOptionField.label
                                            , id = thisOptionModel |> locationFromModel |> locationToString
                                        }
                                        thisOptionModel

                                else
                                    previousOptionFields.view
                                        { config
                                            | label = previousOptionFields.label
                                            , id = "never used"
                                        }
                                        (Sum location meta previousOptionLabelsAndModels)
                                        |> List.drop 1
                        in
                        viewOptionSelector :: viewSelectedOption

                    _ ->
                        [ H.text "Fatal error in `option` view function" ]
        , subscriptions =
            \model ->
                case model of
                    Sum location meta (( _, thisOptionModel ) :: previousOptionLabelsAndModels) ->
                        Sub.batch
                            [ previousOptionFields.subscriptions (Sum location meta previousOptionLabelsAndModels)
                            , thisOptionField.subscriptions thisOptionModel
                            ]

                    _ ->
                        Sub.none
        , submit =
            \_ model ->
                case model of
                    Sum location meta (( _, thisOptionModel ) :: previousOptionLabelsAndModels) ->
                        if meta.selected == List.length previousOptionLabelsAndModels then
                            thisOptionField.submit thisOptionField.checks thisOptionModel

                        else
                            previousOptionFields.submit previousOptionFields.checks (Sum location meta previousOptionLabelsAndModels)

                    _ ->
                        let
                            _ =
                                Debug.log "model" model
                        in
                        Err
                            [ { message = "Fatal error in `option` submit function"
                              , fail = True
                              , locator = locatorFromModel model
                              }
                            ]
        , checks = []
        , send = \_ msg -> never msg
        , intercept = \_ _ -> Nothing
        , label = previousOptionFields.label
        , maybeId = Nothing
        }



{-
   d8888b. d88888b d88888b d888888b d8b   db d88888b d88888b d888888b d88888b db      d8888b.
   88  `8D 88'     88'       `88'   888o  88 88'     88'       `88'   88'     88      88  `8D
   88   88 88ooooo 88ooo      88    88V8o 88 88ooooo 88ooo      88    88ooooo 88      88   88
   88   88 88~~~~~ 88~~~      88    88 V8o88 88~~~~~ 88~~~      88    88~~~~~ 88      88   88
   88  .8D 88.     88        .88.   88  V888 88.     88        .88.   88.     88booo. 88  .8D
   Y8888D' Y88888P YP      Y888888P VP   V8P Y88888P YP      Y888888P Y88888P Y88888P Y8888D'


-}


{-| Begin a definition of the fields you want to use in your forms.
-}
defineFields :
    ctor
    ->
        { ctor : ctor
        , widgets : b -> b
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
    , widgets = NT.define
    , modelGetters = NT.defineGetters
    , modelSetters = NT.defineSetters
    , modelBlanks = NT.define
    , msgGetters = NT.defineGetters
    , msgSetters = NT.defineSetters
    , msgBlanks = NT.define
    , apply = NT.define
    }



{-
    .d8b.  d8888b. d8888b. db   d8b   db d888888b d8888b.  d888b  d88888b d888888b
   d8' `8b 88  `8D 88  `8D 88   I8I   88   `88'   88  `8D 88' Y8b 88'     `~~88~~'
   88ooo88 88   88 88   88 88   I8I   88    88    88   88 88      88ooooo    88
   88~~~88 88   88 88   88 Y8   I8I   88    88    88   88 88  ooo 88~~~~~    88
   88   88 88  .8D 88  .8D `8b d8'8b d8'   .88.   88  .8D 88. ~8~ 88.        88
   YP   YP Y8888D' Y8888D'  `8b8' `8d8'  Y888888P Y8888D'  Y888P  Y88888P    YP


-}


{-| Add a Widget to the definition of the Fields you want to use in your forms.
-}
addWidget :
    Widget () widgetModel widgetMsg output
    ->
        { apply :
            ({ blankModel : formModel
             , blankMsg : formMsg
             , ctor :
                Field formModel formMsg NoId widgetMsg input output -> fields
             }
             -> ( formMsg -> Maybe widgetMsg, previousMsgGetters )
             -> ( Maybe widgetMsg -> formMsg -> formMsg, previousMsgSetters )
             -> ( formModel -> Maybe widgetModel, previousModelGetters )
             -> ( Maybe widgetModel -> formModel -> formModel, previousModelSetters )
             -> ( InnerWidget widgetModel widgetMsg output, previousWidgets )
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : ( InnerWidget widgetModel widgetMsg output, previousWidgets ) -> toWidgets
        , modelBlanks : ( Maybe widgetModel, previousBlankModels ) -> toBlankModel
        , modelGetters :
            { appendToGetters : ( tuple3 -> head3, nextModelGetters ) -> toModelGetters
            , focus : tuple3 -> ( head3, tail4 )
            }
        , modelSetters :
            { appendToSetters :
                ( head2 -> tuple2 -> tuple2, nextModelSetters ) -> toModelSetters
            , focus :
                (( head2, tail3 ) -> ( head2, tail3 )) -> tuple2 -> tuple2
            }
        , msgBlanks : ( Maybe widgetMsg, previousBlankMsgs ) -> toBlankMsg
        , msgGetters :
            { appendToGetters : ( tuple1 -> head1, nextMsgGetters ) -> toMsgGetters
            , focus : tuple1 -> ( head1, tail1 )
            }
        , msgSetters :
            { appendToSetters :
                ( head -> tuple -> tuple, nextMsgSetters ) -> toMsgSetters
            , focus : (( head, tail ) -> ( head, tail )) -> tuple -> tuple
            }
        }
    ->
        { apply :
            ({ blankModel : formModel, blankMsg : formMsg, ctor : fields }
             -> previousMsgGetters
             -> previousMsgSetters
             -> previousModelGetters
             -> previousModelSetters
             -> previousWidgets
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : previousWidgets -> toWidgets
        , modelBlanks : previousBlankModels -> toBlankModel
        , modelGetters :
            { appendToGetters : nextModelGetters -> toModelGetters
            , focus : tuple3 -> tail4
            }
        , modelSetters :
            { appendToSetters : nextModelSetters -> toModelSetters
            , focus : (tail3 -> tail3) -> tuple2 -> tuple2
            }
        , msgBlanks : previousBlankMsgs -> toBlankMsg
        , msgGetters :
            { appendToGetters : nextMsgGetters -> toMsgGetters, focus : tuple1 -> tail1 }
        , msgSetters :
            { appendToSetters : nextMsgSetters -> toMsgSetters
            , focus : (tail -> tail) -> tuple -> tuple
            }
        }
addWidget widget builder =
    { ctor = builder.ctor
    , widgets = NT.appender (widget ()) builder.widgets
    , modelGetters = NT.getter builder.modelGetters
    , modelSetters = NT.setter builder.modelSetters
    , modelBlanks = NT.appender Nothing builder.modelBlanks
    , msgGetters = NT.getter builder.msgGetters
    , msgSetters = NT.setter builder.msgSetters
    , msgBlanks = NT.appender Nothing builder.msgBlanks
    , apply = folder5 applierWithoutConfig builder.apply
    }


{-| Add a configurable Widget to the definition of the Fields you want to use in
your forms. Each time you use a Field derived from this Widget in your form, you
will be able to pass in a `config` value.
-}
addWidgetWithConfig :
    Widget config widgetModel widgetMsg output
    ->
        { apply :
            ({ blankModel : formModel
             , blankMsg : formMsg
             , ctor :
                (config -> Field formModel formMsg NoId widgetMsg input output) -> fields
             }
             -> ( formMsg -> Maybe widgetMsg, previousMsgGetters )
             -> ( Maybe widgetMsg -> formMsg -> formMsg, previousMsgSetters )
             -> ( formModel -> Maybe widgetModel, previousModelGetters )
             -> ( Maybe widgetModel -> formModel -> formModel, previousModelSetters )
             -> ( Widget config widgetModel widgetMsg output, previousWidgets )
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : ( Widget config widgetModel widgetMsg output, previousWidgets ) -> toWidgets
        , modelBlanks : ( Maybe widgetModel, previousBlankModels ) -> toBlankModel
        , modelGetters :
            { appendToGetters : ( tuple3 -> head3, nextModelGetters ) -> toModelGetters
            , focus : tuple3 -> ( head3, tail4 )
            }
        , modelSetters :
            { appendToSetters :
                ( head2 -> tuple2 -> tuple2, nextModelSetters ) -> toModelSetters
            , focus :
                (( head2, tail3 ) -> ( head2, tail3 )) -> tuple2 -> tuple2
            }
        , msgBlanks : ( Maybe widgetMsg, previousBlankMsgs ) -> toBlankMsg
        , msgGetters :
            { appendToGetters : ( tuple1 -> head1, nextMsgGetters ) -> toMsgGetters
            , focus : tuple1 -> ( head1, tail1 )
            }
        , msgSetters :
            { appendToSetters :
                ( head -> tuple -> tuple, nextMsgSetters ) -> toMsgSetters
            , focus : (( head, tail ) -> ( head, tail )) -> tuple -> tuple
            }
        }
    ->
        { apply :
            ({ blankModel : formModel, blankMsg : formMsg, ctor : fields }
             -> previousMsgGetters
             -> previousMsgSetters
             -> previousModelGetters
             -> previousModelSetters
             -> previousWidgets
             -> accForNext
            )
            -> toFolder5
        , ctor : f
        , widgets : previousWidgets -> toWidgets
        , modelBlanks : previousBlankModels -> toBlankModel
        , modelGetters :
            { appendToGetters : nextModelGetters -> toModelGetters
            , focus : tuple3 -> tail4
            }
        , modelSetters :
            { appendToSetters : nextModelSetters -> toModelSetters
            , focus : (tail3 -> tail3) -> tuple2 -> tuple2
            }
        , msgBlanks : previousBlankMsgs -> toBlankMsg
        , msgGetters :
            { appendToGetters : nextMsgGetters -> toMsgGetters, focus : tuple1 -> tail1 }
        , msgSetters :
            { appendToSetters : nextMsgSetters -> toMsgSetters
            , focus : (tail -> tail) -> tuple -> tuple
            }
        }
addWidgetWithConfig widget builder =
    { ctor = builder.ctor
    , widgets = NT.appender widget builder.widgets
    , modelGetters = NT.getter builder.modelGetters
    , modelSetters = NT.setter builder.modelSetters
    , modelBlanks = NT.appender Nothing builder.modelBlanks
    , msgGetters = NT.getter builder.msgGetters
    , msgSetters = NT.setter builder.msgSetters
    , msgBlanks = NT.appender Nothing builder.msgBlanks
    , apply = folder5 applierWithConfig builder.apply
    }



{-
   d88888b d8b   db d8888b. d88888b d888888b d88888b db      d8888b. .d8888.
   88'     888o  88 88  `8D 88'       `88'   88'     88      88  `8D 88'  YP
   88ooooo 88V8o 88 88   88 88ooo      88    88ooooo 88      88   88 `8bo.
   88~~~~~ 88 V8o88 88   88 88~~~      88    88~~~~~ 88      88   88   `Y8b.
   88.     88  V888 88  .8D 88        .88.   88.     88booo. 88  .8D db   8D
   Y88888P VP   V8P Y8888D' YP      Y888888P Y88888P Y88888P Y8888D' `8888Y'


-}


{-| Finalize the definition of the Fields you want to use in your forms.
-}
endFields :
    { apply :
        (acc -> empty -> empty -> empty -> empty -> empty -> acc)
        -> { blankModel : modelBlanks, blankMsg : msgBlanks, ctor : toFields }
        -> msgGetters
        -> msgSetters
        -> modelGetters
        -> modelSetters
        -> widgets
        -> { blankModel : modelBlanks, blankMsg : msgBlanks, ctor : fields }
    , ctor : toFields
    , widgets : () -> widgets
    , modelBlanks : () -> modelBlanks
    , modelGetters : { appendToGetters : () -> modelGetters, focus : focus3 }
    , modelSetters : { appendToSetters : () -> modelSetters, focus : focus2 }
    , msgBlanks : () -> msgBlanks
    , msgGetters : { appendToGetters : () -> msgGetters, focus : focus1 }
    , msgSetters : { appendToSetters : () -> msgSetters, focus : focus }
    }
    -> fields
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

        widgets =
            NT.endAppender builder.widgets

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
        widgets
        |> .ctor



{-
   d8888b.  .d8b.  d8888b. db   dD      .88b  d88.  .d8b.   d888b  d888888b  .o88b.
   88  `8D d8' `8b 88  `8D 88 ,8P'      88'YbdP`88 d8' `8b 88' Y8b   `88'   d8P  Y8
   88   88 88ooo88 88oobY' 88,8P        88  88  88 88ooo88 88         88    8P
   88   88 88~~~88 88`8b   88`8b        88  88  88 88~~~88 88  ooo    88    8b
   88  .8D 88   88 88 `88. 88 `88.      88  88  88 88   88 88. ~8~   .88.   Y8b  d8
   Y8888D' YP   YP 88   YD YP   YD      YP  YP  YP YP   YP  Y888P  Y888888P  `Y88P'


-}


applierWithConfig :
    (formMsg -> Maybe widgetMsg)
    -> (Maybe widgetMsg -> formMsg -> formMsg)
    -> (formModel -> Maybe widgetModel)
    -> (Maybe widgetModel -> formModel -> formModel)
    -> Widget config widgetModel widgetMsg output
    ->
        { blankModel : formModel
        , blankMsg : formMsg
        , ctor : (config -> Field formModel formMsg NoId widgetMsg input output) -> fields
        }
    -> { blankModel : formModel, blankMsg : formMsg, ctor : fields }
applierWithConfig msgGetter msgSetter modelGetter modelSetter widgetFromConfig acc =
    let
        send_ msg_ =
            msgSetter (Just msg_) acc.blankMsg

        intercept_ =
            msgGetter

        field_ config =
            let
                widget =
                    widgetFromConfig config
            in
            convertToField
                { init =
                    let
                        ( widgetModel, widgetCmd ) =
                            widget.init
                    in
                    ( modelSetter (Just widgetModel) acc.blankModel
                    , Cmd.map send_ widgetCmd
                    )
                , load = \input model -> modelSetter input model
                , update =
                    \msg model ->
                        case
                            Maybe.map2 widget.update (msgGetter msg) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , view =
                    \viewConfig model ->
                        Maybe.map (widget.view viewConfig) (modelGetter model)
                            |> Maybe.withDefault []
                            |> List.map (H.map send_)
                , submit =
                    \model ->
                        modelGetter model
                            |> Maybe.map
                                (\mdl ->
                                    widget.submit mdl
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
                        Maybe.map widget.subscriptions (modelGetter model)
                            |> Maybe.withDefault Sub.none
                            |> Sub.map send_
                , label = widget.label
                , send = send_
                , intercept = intercept_
                , blankModel = acc.blankModel
                }
    in
    { ctor = acc.ctor field_
    , blankMsg = acc.blankMsg
    , blankModel = acc.blankModel
    }


applierWithoutConfig :
    (formMsg -> Maybe widgetMsg)
    -> (Maybe widgetMsg -> formMsg -> formMsg)
    -> (formModel -> Maybe widgetModel)
    -> (Maybe widgetModel -> formModel -> formModel)
    -> InnerWidget widgetModel widgetMsg output
    ->
        { blankModel : formModel
        , blankMsg : formMsg
        , ctor : Field formModel formMsg NoId widgetMsg input output -> fields
        }
    -> { blankModel : formModel, blankMsg : formMsg, ctor : fields }
applierWithoutConfig msgGetter msgSetter modelGetter modelSetter widget acc =
    let
        send_ msg_ =
            msgSetter (Just msg_) acc.blankMsg

        intercept_ =
            msgGetter

        field_ =
            convertToField
                { init =
                    let
                        ( widgetModel, widgetCmd ) =
                            widget.init
                    in
                    ( modelSetter (Just widgetModel) acc.blankModel
                    , Cmd.map send_ widgetCmd
                    )
                , load = \input model -> modelSetter input model
                , update =
                    \msg model ->
                        case
                            Maybe.map2 widget.update (msgGetter msg) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
                , view =
                    \viewConfig model ->
                        Maybe.map (widget.view viewConfig) (modelGetter model)
                            |> Maybe.withDefault []
                            |> List.map (H.map send_)
                , submit =
                    \model ->
                        modelGetter model
                            |> Maybe.map
                                (\mdl ->
                                    widget.submit mdl
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
                        Maybe.map widget.subscriptions (modelGetter model)
                            |> Maybe.withDefault Sub.none
                            |> Sub.map send_
                , label = widget.label
                , send = send_
                , intercept = intercept_
                , blankModel = acc.blankModel
                }
    in
    { ctor = acc.ctor field_
    , blankMsg = acc.blankMsg
    , blankModel = acc.blankModel
    }


convertToField :
    { init : ( formModel, Cmd formMsg )
    , load : input -> formModel -> formModel
    , update : formMsg -> formModel -> ( formModel, Cmd formMsg )
    , blankModel : formModel
    , view : ViewConfig -> formModel -> List (H.Html formMsg)
    , submit : formModel -> Result (List InternalFeedback) value
    , subscriptions : formModel -> Sub formMsg
    , send : widgetMsg -> formMsg
    , intercept : formMsg -> Maybe widgetMsg
    , label : String
    }
    -> Field formModel formMsg NoId widgetMsg input value
convertToField args =
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
        , load =
            \input model ->
                case model of
                    Value location innerModel ->
                        args.load input innerModel |> Value location

                    _ ->
                        model
        , update =
            \msg model ->
                case model of
                    Value location innerModel ->
                        case msg of
                            ValueChanged locator widgetMsg ->
                                if isLocated locator location then
                                    let
                                        ( newModel, cmd ) =
                                            args.update widgetMsg innerModel
                                    in
                                    ( Value location newModel
                                    , Cmd.map (ValueChanged (locationToLocator location)) cmd
                                    )

                                else
                                    ( model, Cmd.none )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \viewConfig model ->
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
                            viewConfig.feedback

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
                    , label = viewConfig.label
                    }
                    model_
                    |> List.map (H.map mapper)
        , submit =
            \checks model ->
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
                            |> Result.andThen (runChecks checks model)

                    _ ->
                        Err []
        , checks = []
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
                    ( Just id_, ValueChanged (ById msgId) msgTuple ) ->
                        if msgId == id_ then
                            args.intercept msgTuple

                        else
                            Nothing

                    _ ->
                        Nothing
        , label = args.label
        , maybeId = Nothing
        }


runChecks :
    List ( MaybeId, output2 -> Maybe String )
    -> Node formModel
    -> output2
    ->
        Result
            (List
                { message : String
                , fail : Bool
                , locator : Locator
                }
            )
            output2
runChecks checks model output =
    case
        List.filterMap
            (\( maybeId, check ) ->
                check output
                    |> Maybe.map
                        (\m ->
                            { message = m
                            , fail = True
                            , locator =
                                case maybeId of
                                    Nothing ->
                                        locatorFromModel model

                                    Just id_ ->
                                        ById id_
                            }
                        )
            )
            checks
    of
        [] ->
            Ok output

        errs ->
            Err errs


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


pathToString : List Int -> String
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

        productTypeToString productType =
            case productType of
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
                    , nodeLabel loc (productTypeToString typ).label
                    , (productTypeToString typ).shape
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



{-
   .d8888. d888888b db    db d8888b. d888888b  .d88b.
   88'  YP `~~88~~' 88    88 88  `8D   `88'   .8P  Y8.
   `8bo.      88    88    88 88   88    88    88    88
     `Y8b.    88    88    88 88   88    88    88    88
   db   8D    88    88b  d88 88  .8D   .88.   `8b  d8'
   `8888Y'    YP    ~Y8888P' Y8888D' Y888888P  `Y88P'


-}


{-| Turn a [`Field`](#Field) into an Elm `Program` that you can view in your
browser with in `elm reactor` for testing purposes.

This should only be used in development - to help you avoid accidentally
deploying it in production, you should pass in `Debug.toString` as the first
argument.

-}
studio :
    (output -> String)
    -> Field formModel formMsg id widgetMsg input output
    -> Program () (Model formModel output) (Msg formMsg)
studio debugToString field =
    Browser.document
        { init = \() -> init field
        , update = update field
        , view =
            \model ->
                { title = "Yafl Studio"
                , body =
                    [ H.h1 [] [ H.text "Your form" ]
                    , H.form []
                        (view field model
                         --|> List.map (\item -> H.div [] [ item ])
                        )
                    , H.h2 [] [ H.text "Output" ]
                    , case submit field model of
                        Ok output ->
                            H.div []
                                [ H.text "Validation succeeded!"
                                , H.pre [] [ H.text (debugToString output) ]
                                ]

                        Err errors ->
                            H.div []
                                [ H.text "Validation failed!"
                                , H.ul [] <|
                                    List.map
                                        (\( id_, err ) ->
                                            H.li [] [ H.text (id_ ++ ": " ++ err) ]
                                        )
                                        errors
                                ]
                    ]
                }
        , subscriptions = subscriptions field
        }
