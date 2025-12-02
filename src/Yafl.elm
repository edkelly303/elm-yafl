module Yafl exposing
    ( Widget
    , Field, defineFields, addWidget, addWidgetWithConfig, endFields
    , Model, Msg, init, load, update, view, viewWizard, ViewConfig, Feedback, subscriptions, submit
    , succeed, fail, failAt
    , map, contraMap
    , andMap, andThen
    , choice, option
    , label, html
    , validate, validateAt
    , HasId, NoId, identifier, intercept, send, isFormValid
    , studio, toDOT
    )

{-| This library helps you build user input forms in Elm by creating and
composing self-contained [`Widget`](#Widget)s.


## Table of contents


### [Creating Widgets](#creating-widgets)

[`Widget`](#Widget)


### [Turning Widgets into Fields](#turning-widgets-into-fields)

[`Field`](#Field), [`defineFields`](#defineFields), [`addWidget`](#addWidget),
[`addWidgetWithConfig`](#addWidgetWithConfig), [`endFields`](#endFields)


### [Turning Fields into forms](#turning-fields-into-forms)

[`Model`](#Model), [`Msg`](#Msg), [`init`](#init), [`load`](#load),
[`update`](#update), [`view`](#view), [`viewWizard`](#viewWizard), [`ViewConfig`](#ViewConfig),
[`Feedback`](#Feedback), [`subscriptions`](#subscriptions), [`submit`](#submit)


### [Combining Fields](#combining-fields)

[`succeed`](#succeed), [`fail`](#fail), [`failAt`](#failAt), [`map`](#map),
[`map2`](#map2), [`andMap`](#andMap), [`andThen`](#andThen), [`choice`](#choice), [`option`](#option)


### [Customizing Fields](#customizing-fields)

[`label`](#label), [`html`](#html)


### [Validating fields](#validating-fields)

[`validate`](#validate), [`validateAt`](#validateAt)


### [Communicating between Fields](#communicating-between-fields)

[`HasId`](#HasId), [`NoId`](#NoId), [`identifier`](#identifier),
[`intercept`](#intercept), [`send`](#send)


### [Debugging](#debugging)

[`studio`](#studio), [`toDOT`](#toDOT)


# Creating Widgets

[_Back to top_](#table-of-contents)

[`Widget`](#Widget)s are the basic building blocks of this package. Each widget
is effectively a little Elm application, with its own `init`, `update`, `view`
and `subscriptions` functions, plus a couple of extra features.

This package doesn't supply any prebuilt widgets. Every app is unique, and it's
unlikely that a prebuilt widget would precisely fit your use case. But the point
is, this package gives you the power to create _any_ types of widgets you
choose, and compose them together very easily with minimal boilerplate.

Nevertheless, we'll provide some code samples for a few simple widgets that we
can use in the code snippets in these docs.

    module Examples exposing (..)

    import Html as H
    import Html.Attributes as HA
    import Html.Events as HE
    import Yafl

    {-| A basic `Widget` that produces a `String`. Its internal
    `model` and `msg` types are also `String`s.
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

    {-| A `Widget` that produces an `Int`, based on the counter
    example from the Elm Guide. Its internal `model` type is an
    `Int`, but its `msg` type is a custom type.
    -}
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
        Yafl.defineFields
            (\string counter -> { string = string, counter = counter })
            |> Yafl.addWidget stringWidget
            |> Yafl.addWidget counterWidget
            |> Yafl.endFields

    {- This gives us the following Model and Msg types for
       our form:
    -}
    type alias FormModel =
        ( Maybe String, ( Maybe Int, () ) )

    type alias FormMsg =
        ( Maybe String, ( Maybe CounterMsg, () ) )

@docs Field, defineFields, addWidget, addWidgetWithConfig, endFields


# Turning Fields into forms

Once we've defined our [`Field`](#Field)s, we can start the fun part: making forms!

Imagine we just want a simple form that allows a user to choose an `Int`:

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)
    import Html exposing (Html)

    -- We can turn any Field into a form:

    form =
        fields.counter

    -- Initialize it with `Yafl.init` to get a (model, cmd)
    -- tuple:

    init =
        Yafl.init form

    init

    --: ( Yafl.Model FormModel Int, Cmd (Yafl.Msg FormMsg) )

    -- The form's model can then be passed to `Yafl.view`,
    -- `Yafl.update`, `Yafl.subscriptions` and `Yafl.submit`:

    model =
        Tuple.first init

    Yafl.view form model

    --: List (Html (Yafl.Msg FormMsg))

    Yafl.subscriptions form model

    --: Sub (Yafl.Msg FormMsg)

    Yafl.submit form model

    --> Ok 0

@docs Model, Msg, init, load, update, view, viewWizard, ViewConfig, Feedback, subscriptions, submit


# Combining Fields

[_Back to top_](#table-of-contents)


## Succeeding and failing

In addition to the [`Field`](#Field)s that you define based on your
[`Widget`](#Widget)s, the package also provides [`succeed`](#succeed) and
[`fail`](#fail), which can be useful in various ways when
used with other combinators such as [`andMap`](#andMap). You may be familiar with similar functions from packages
such as [`elm/json`](http://package.elm-lang.org/packages/elm/json/latest/Json-Decode#succeed).

The views of these fields return an empty Html element. When
submitted, `succeed` always returns an `Ok`, while `fail` always returns an
`Err`.

@docs succeed, fail, failAt


## Converting output types

@docs map, contraMap


## Building product types

@docs map2, andMap, andThen


## Building custom types

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    type MyCustomType
        = Foo String
        | Bar Int

    myCustomTypeField =
        Yafl.choice
            |> Yafl.option "Foo" .foo fooField
            |> Yafl.option "Bar" .bar barField

    fooField =
        fields.string
            |> Yafl.map Foo

    barField =
        fields.counter
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

@docs label, html


# Validating fields

[_Back to top_](#table-of-contents)

@docs validate, validateAt


# Communicating between Fields

[_Back to top_](#table-of-contents)

@docs HasId, NoId, identifier, intercept, send, isFormValid


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
    = Model { selected : Int } (Node formModel)


type Node formModel
    = Value Location formModel
    | Product Location (List (Node formModel))
    | Sum Location { selected : Int, last : Int } (List ( String, Node formModel ))
    | Empty EmptyType Location


type EmptyType
    = Succeed
    | Fail


{-| The top-level message type for your form.
-}
type Msg formMsg
    = ValueChanged Locator formMsg
    | OptionSelected Path Int
    | Noop


{-| An internal data type used to track the location of a [`Field`](#Field) within the form.
-}
type alias Path =
    List Int


{-| Forms are composed of `Field`s - this is the main data type we'll be using in this package.
-}
type Field formModel formMsg id widgetMsg input output
    = Field
        { init :
            Path -> MaybeId -> ( Node formModel, Cmd (Msg formMsg) )
        , load : Maybe input -> Node formModel -> ( Node formModel, Cmd (Msg formMsg) )
        , update :
            Msg formMsg
            -> Node formModel
            -> ( Node formModel, Cmd (Msg formMsg) )
        , view :
            InternalViewConfig
            -> Node formModel
            -> View formMsg
        , submit :
            List ( MaybeId, output -> Maybe String )
            -> Node formModel
            -> Result (List InternalFeedback) output
        , checks : List ( MaybeId, output -> Maybe String )
        , subscriptions :
            Node formModel
            -> Sub (Msg formMsg)
        , send : MaybeId -> widgetMsg -> Msg formMsg
        , intercept : MaybeId -> Msg formMsg -> Maybe widgetMsg
        , label : String
        , maybeId : MaybeId
        }


type View formMsg
    = ViewNone
    | ViewOne (List (H.Html (Msg formMsg)))
    | ViewMany (View formMsg) (List (View formMsg))


{-| Indicates that a [`Field`](#Field) has been given an `identifier`, and can therefore be
used with [`intercept`](#intercept), [`send`](#send), etc. See the docs for [`identifier`](#identifier).
-}
type HasId
    = HasId Never


{-| Indicates that a [`Field`](#Field) has not been given an `identifier`. See the docs for
[`identifier`](#identifier).
-}
type NoId
    = NoId Never


{-| The `Widget` type is very similar to the record type that you would supply
to [`Browser.element`](http://package.elm-lang.org/packages/elm/browser/latest/Browser#element) to create
an Elm [`Program`](http://package.elm-lang.org/packages/elm/core/latest/Platform#Program).
-}
type alias Widget config model msg output =
    config
    -> InnerWidget model msg output


type alias InnerWidget model msg output =
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

    fields.counter
        |> Yafl.init

    --: ( Yafl.Model FormModel Int, Cmd (Yafl.Msg FormMsg) )

-}
init :
    Field formModel formMsg id widgetMsg input output
    -> ( Model formModel output, Cmd (Msg formMsg) )
init (Field field) =
    let
        ( node, cmd ) =
            field.init [ 0 ] field.maybeId
    in
    ( Model { selected = 0 } node, cmd )


{-| Check that a form doesn't contain fields with duplicate identifiers.
-}
isFormValid : Field formModel formMsg id widgetMsg input output -> Bool
isFormValid field =
    let
        check (Model _ node) =
            List.isEmpty (checkDuplicateIds node)
    in
    init field
        |> Tuple.first
        |> check


checkDuplicateIds : Node a -> List ( String, Int )
checkDuplicateIds node =
    let
        locationToId l =
            case l of
                Identified _ id_ ->
                    Just id_

                Located _ ->
                    Nothing

        help output n =
            case n of
                Value loc _ ->
                    locationToId loc :: output

                Product loc ns ->
                    locationToId loc :: List.concatMap (help []) ns ++ output

                Sum loc _ ns ->
                    locationToId loc :: List.concatMap (Tuple.second >> help []) ns ++ output

                Empty _ loc ->
                    locationToId loc :: output
    in
    help [] node
        |> List.filterMap identity
        |> List.Extra.frequencies
        |> List.filter (\( _, count ) -> count > 1)



{-
   db       .d88b.   .d8b.  d8888b.
   88      .8P  Y8. d8' `8b 88  `8D
   88      88    88 88ooo88 88   88
   88      88    88 88~~~88 88   88
   88booo. `8b  d8' 88   88 88  .8D
   Y88888P  `Y88P'  YP   YP Y8888D'

-}


{-| Load data into your form. A bit tricky to explain, but see the examples
below:

For simple `Field`s, you just pass a value of the underlying `Widget`'s `msg`
type. This will dispatch the `msg` to the `Field`'s update function, which may
then update its model and optionally send a `Cmd`.

    import Yafl
    import Examples exposing (FormModel, FormMsg, CounterMsg(..), fields)

    form =
        fields.counter

    modelBeforeLoading =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form modelBeforeLoading
    --> Ok 0

    modelAfterLoading =
        modelBeforeLoading
            |> Yafl.load form Increment
            |> Tuple.first

    Yafl.submit form modelAfterLoading
    --> Ok 1

For `Field`s composed using `map2` or `andMap`, you can pass in a record where
each field is a `Maybe widgetMsg`. If the record field's value is `Just`, then
the message will be dispatched to the `Field`'s update function. If it's
`Nothing`, then no message will be dispatched and the `Field`'s model will
remain unchanged.

    import Yafl
    import Examples exposing (FormModel, FormMsg, CounterMsg(..), fields)

    form =
        Yafl.succeed (\int string -> ( int, string ))
            |> Yafl.andMap .a fields.counter
            |> Yafl.andMap .b fields.string

    form
    --: Yafl.Field FormModel FormMsg Never Never { a : Maybe CounterMsg, b : Maybe String } ( Int, String )

    modelBeforeLoading =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form modelBeforeLoading
    --> Ok (0, "")

    modelAfterLoading =
        modelBeforeLoading
            |> Yafl.load form
                { a = Nothing
                , b = Just "hello"
                }
            |> Tuple.first

    Yafl.submit form modelAfterLoading
    --> Ok ( 0, "hello" )

For `Field`s composed using `choice` and `option`, it's a similar story, except
that the options are nested within a record of the form `{ selected : Maybe Int,
options : {...} }`. The `selected` field is used to pick which of the options
should be selected (it's zero-indexed, so 0 is the first option, 1 is the
second, etc.)

    import Yafl
    import Examples exposing (FormModel, FormMsg, CounterMsg(..), fields)

    type Foo
        = Bar Int
        | Qux String

    form =
        Yafl.choice
            |> Yafl.option "Bar" .bar barField
            |> Yafl.option "Qux" .qux quxField

    barField =
        Yafl.map Bar fields.counter

    quxField =
        Yafl.map Qux fields.string

    form
    --: Yafl.Field FormModel FormMsg Never Never { selected : Maybe Int, options : Maybe { bar : Maybe CounterMsg, qux : Maybe String } } Foo

    modelBeforeLoading =
        form
            |> Yafl.init
            |> Tuple.first

    Yafl.submit form modelBeforeLoading
    --> Ok (Bar 0)

    modelAfterLoading =
        modelBeforeLoading
            |> Yafl.load form
                { selected = Just 1
                , options =
                    Just
                        { bar = Nothing
                        , qux = Just "hello"
                        }
                }
            |> Tuple.first

    Yafl.submit form modelAfterLoading
    --> Ok (Qux "hello")

-}
load :
    Field formModel formMsg id widgetMsg input output
    -> input
    -> Model formModel output
    -> ( Model formModel output, Cmd (Msg formMsg) )
load (Field field) input (Model meta node) =
    field.load (Just input) node
        |> Tuple.mapFirst (Model meta)



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
update (Field field) msg (Model meta node) =
    case msg of
        OptionSelected [] n ->
            case node of
                Product _ ns ->
                    ( Model { meta | selected = clamp 0 (List.length ns - 1) n } node
                    , Cmd.none
                    )

                _ ->
                    ( Model meta node, Cmd.none )

        _ ->
            field.update msg node
                |> Tuple.mapFirst (Model meta)



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
view (Field field) (Model _ model) =
    let
        feedback =
            case field.submit field.checks model of
                Ok _ ->
                    []

                Err f ->
                    f
    in
    checkDuplicatesErrorView model
        :: (field.view
                { label = field.label
                , feedback = feedback
                , id = locationFromModel model |> locationToString
                }
                model
                |> viewToList []
           )



{-
   db    db d888888b d88888b db   d8b   db db   d8b   db d888888b d88888D  .d8b.  d8888b. d8888b.
   88    88   `88'   88'     88   I8I   88 88   I8I   88   `88'   YP  d8' d8' `8b 88  `8D 88  `8D
   Y8    8P    88    88ooooo 88   I8I   88 88   I8I   88    88       d8'  88ooo88 88oobY' 88   88
   `8b  d8'    88    88~~~~~ Y8   I8I   88 Y8   I8I   88    88      d8'   88~~~88 88`8b   88   88
    `8bd8'    .88.   88.     `8b d8'8b d8' `8b d8'8b d8'   .88.    d8' db 88   88 88 `88. 88  .8D
      YP    Y888888P Y88888P  `8b8' `8d8'   `8b8' `8d8'  Y888888P d88888P YP   YP 88   YD Y8888D'


-}


{-| View your form as a multi-step wizard. This will only work if the top level
of your form is a product type created with `succeed` and `andMap`.
-}
viewWizard :
    Field formModel formMsg id widgetMsg input output
    -> Model formModel output
    ->
        { stepView : List (H.Html (Msg formMsg))
        , stepIndex : Int
        , totalSteps : Int
        , backMsg : Maybe (Msg formMsg)
        , nextMsg : Maybe (Msg formMsg)
        , selectStepMsg : Int -> Msg formMsg
        }
viewWizard (Field field) (Model meta model) =
    let
        feedback =
            case field.submit field.checks model of
                Ok _ ->
                    []

                Err f ->
                    f

        toList =
            viewToList []

        default =
            { stepView = []
            , nextMsg = Nothing
            , backMsg = Nothing
            , selectStepMsg = OptionSelected []
            , stepIndex = meta.selected
            , totalSteps = 0
            }
    in
    case field.view { label = field.label, feedback = feedback, id = locationFromModel model |> locationToString } model of
        ViewMany v vs ->
            let
                currentPage =
                    (v :: vs)
                        |> List.reverse
                        |> List.Extra.getAt meta.selected
                        |> Maybe.map toList
                        |> Maybe.withDefault []

                totalSteps =
                    List.length (v :: vs)
            in
            { default
                | stepView = checkDuplicatesErrorView model :: currentPage
                , nextMsg =
                    if meta.selected < totalSteps - 1 then
                        Just (OptionSelected [] (meta.selected + 1))

                    else
                        Nothing
                , backMsg =
                    if meta.selected > 0 then
                        Just (OptionSelected [] (meta.selected - 1))

                    else
                        Nothing
                , totalSteps = totalSteps
            }

        otherView ->
            { default | stepView = checkDuplicatesErrorView model :: toList otherView }


viewToList : List (H.Html (Msg formMsg)) -> View formMsg -> List (H.Html (Msg formMsg))
viewToList acc v =
    case v of
        ViewNone ->
            acc

        ViewOne one ->
            one ++ acc

        ViewMany one more ->
            List.foldl (\v_ acc_ -> viewToList acc_ v_) acc (one :: more)


checkDuplicatesErrorView : Node formModel -> H.Html msg
checkDuplicatesErrorView model =
    case checkDuplicateIds model of
        [] ->
            H.text ""

        dups ->
            H.div
                []
                (List.map
                    (\( id_, count ) ->
                        H.p []
                            [ H.strong []
                                [ H.text
                                    ("⚠️ FATAL ERROR IN FORM DEFINITION: field identifiers must be unique, but the identifier \""
                                        ++ id_
                                        ++ "\" is assigned to "
                                        ++ String.fromInt count
                                        ++ " different fields."
                                    )
                                ]
                            ]
                    )
                    dups
                )



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
subscriptions (Field field) (Model _ model) =
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
submit (Field field) (Model _ model) =
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

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

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
            |> Yafl.identifier "password"

    confirmField =
        fields.string
            |> Yafl.identifier "confirm"

    form =
        Yafl.succeed
            (\password confirm -> { password = password, confirm = confirm })
            |> Yafl.andMap .passwordField passwordField
            |> Yafl.andMap .confirmField confirmField
            |> Yafl.validateAt confirmField
                (\{ password, confirm } ->
                    if password == confirm then
                        Nothing
                    else
                        Just "Passwords do not match"
                )

    form
        |> Yafl.init
        |> Tuple.first
        |> Yafl.load form
            { passwordField = Just "password123"
            , confirmField = Just "password124"
            }
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

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

    myFieldWithId =
        myField
            |> Yafl.identifier "any-string-as-long-as-it's-unique"

    myFieldWithId

    --: Yafl.Field FormModel FormMsg Yafl.HasId String String String

    Yafl.send myFieldWithId "Hello!"

    --: Cmd (Yafl.Msg FormMsg)

This identifier is also used as the `id` string in [`ViewConfig`](#ViewConfig),
which is passed into the view when the Field is rendered. When defining a
Widget, you can use the `id` field of the `ViewConfig` to set the
`Html.Attributes.id` of the HTML input.

-}
identifier :
    String
    -> Field formModel formMsg NoId widgetMsg input output
    -> Field formModel formMsg HasId widgetMsg input output
identifier sendId_ (Field field) =
    Field { field | maybeId = Just sendId_ }



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
            |> Yafl.identifier "any-string-as-long-as-it's-unique"

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
            |> Yafl.identifier "any-string-as-long-as-it's-unique"

    Yafl.intercept myFieldWithId

    --: Yafl.Msg FormMsg -> Maybe String

-}
intercept : Field formModel formMsg HasId widgetMsg input output -> Msg formMsg -> Maybe widgetMsg
intercept (Field field) =
    field.intercept field.maybeId



{-
   db   db d888888b .88b  d88. db
   88   88 `~~88~~' 88'YbdP`88 88
   88ooo88    88    88  88  88 88
   88~~~88    88    88  88  88 88
   88   88    88    88  88  88 88booo.
   YP   YP    YP    YP  YP  YP Y88888P


-}


{-| Add some arbitrary HTML after the preceding field

    import Examples exposing (FormModel, FormMsg, fields)
    import Html
    import Yafl

    form =
        Yafl.succeed (\string1 string2 -> ())
            |> Yafl.andMap .string1 fields.string
            |> Yafl.html (Html.text "Here's some text between two string inputs")
            |> Yafl.andMap .string2 fields.string

    form --: Yafl.Field FormModel FormMsg Never Never {string1 : Maybe String, string2 : Maybe String } ()

-}
html :
    H.Html Never
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output
html html_ (Field field) =
    Field
        { field
            | view =
                \config model ->
                    case field.view config model of
                        ViewNone ->
                            ViewNone

                        ViewOne v ->
                            ViewOne (v ++ [ H.map (always Noop) html_ ])

                        ViewMany v vs ->
                            ViewMany v
                                (vs
                                    |> List.reverse
                                    |> (::) (ViewOne [ H.map (always Noop) html_ ])
                                    |> List.reverse
                                )
                                |> Debug.log "This is probably not what we want, we should add the html_ to the last element of ViewMany"
        }



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
succeed : output -> Field formModel formMsg Never Never input output
succeed output =
    Field
        { init = \path maybeId -> ( Empty Succeed (newLocation path maybeId), Cmd.none )
        , load = \_ model -> ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> ViewNone
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
fail : String -> Field formModel formMsg Never Never input output
fail e =
    Field
        { init = \path maybeId -> ( Empty Fail (newLocation path maybeId), Cmd.none )
        , load = \_ model -> ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view =
            \{ feedback } model ->
                ViewOne <|
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
    -> Field formModel formMsg Never Never input2 output2
failAt (Field failField) e =
    Field
        { init = \path maybeId -> ( Empty Fail (newLocation path maybeId), Cmd.none )
        , load = \_ model -> ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view =
            \{ feedback } model ->
                ViewOne <|
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
    .o88b.  .d88b.  d8b   db d888888b d8888b.  .d8b.  .88b  d88.  .d8b.  d8888b.
   d8P  Y8 .8P  Y8. 888o  88 `~~88~~' 88  `8D d8' `8b 88'YbdP`88 d8' `8b 88  `8D
   8P      88    88 88V8o 88    88    88oobY' 88ooo88 88  88  88 88ooo88 88oodD'
   8b      88    88 88 V8o88    88    88`8b   88~~~88 88  88  88 88~~~88 88~~~
   Y8b  d8 `8b  d8' 88  V888    88    88 `88. 88   88 88  88  88 88   88 88
    `Y88P'  `Y88P'  VP   V8P    YP    88   YD YP   YP YP  YP  YP YP   YP 88


-}


{-| Contramap
-}
contraMap :
    (input2 -> input)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input2 output
contraMap f (Field field) =
    Field
        { init = field.init
        , load = \input -> input |> Maybe.map f |> field.load
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , maybeId = field.maybeId
        , send = field.send
        , checks = field.checks
        , intercept = field.intercept
        , label = field.label
        , submit = field.submit
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
        , load = field.load
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
    .d8b.  d8b   db d8888b. .88b  d88.  .d8b.  d8888b.
   d8' `8b 888o  88 88  `8D 88'YbdP`88 d8' `8b 88  `8D
   88ooo88 88V8o 88 88   88 88  88  88 88ooo88 88oodD'
   88~~~88 88 V8o88 88   88 88  88  88 88~~~88 88~~~
   88   88 88  V888 88  .8D 88  88  88 88   88 88
   YP   YP VP   V8P Y8888D' YP  YP  YP YP   YP 88


-}


{-| Combine multiple fields. Use in combination with [`succeed`](#succeed).

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    form =
        Yafl.succeed (\a b c -> { firstName = a, middleName = b, lastName = c })
            |> Yafl.andMap .firstName (fields.string |> Yafl.label "First name")
            |> Yafl.andMap .middleName (fields.string |> Yafl.label "Middle name")
            |> Yafl.andMap .lastName (fields.string |> Yafl.label "Last name")

    model =
        Yafl.init form
            |> Tuple.first

    Yafl.submit form model
    --> Ok { firstName = "", middleName = "", lastName = "" }

-}
andMap :
    (options -> Maybe input)
    -> Field formModel formMsg id widgetMsg input output1
    -> Field formModel formMsg Never Never options (output1 -> output2)
    -> Field formModel formMsg Never Never options output2
andMap getInput (Field thisOptionField) (Field previousOptionFields) =
    Field
        { init =
            \path maybeId ->
                let
                    ( previousOptionModel, previousOptionCmd ) =
                        previousOptionFields.init path previousOptionFields.maybeId
                in
                case previousOptionModel of
                    Product location previousOptions ->
                        let
                            ( thisOptionModel, thisOptionCmd ) =
                                thisOptionField.init (List.length previousOptions :: path) thisOptionField.maybeId
                        in
                        ( Product location (thisOptionModel :: previousOptions)
                        , Cmd.batch [ previousOptionCmd, thisOptionCmd ]
                        )

                    Empty _ _ ->
                        let
                            ( thisOptionModel, thisOptionCmd ) =
                                thisOptionField.init (0 :: path) thisOptionField.maybeId
                        in
                        ( Product (newLocation path maybeId) [ thisOptionModel ]
                        , Cmd.batch [ thisOptionCmd ]
                        )

                    _ ->
                        let
                            ( newPreviousOptionModel, _ ) =
                                previousOptionFields.init (0 :: path) previousOptionFields.maybeId

                            ( thisOptionModel, thisOptionCmd ) =
                                thisOptionField.init (1 :: path) thisOptionField.maybeId
                        in
                        ( Product (newLocation path maybeId) [ thisOptionModel, newPreviousOptionModel ]
                        , Cmd.batch [ previousOptionCmd, thisOptionCmd ]
                        )
        , load =
            \input model ->
                case ( input |> Maybe.andThen getInput, model ) of
                    ( thisOptionInput, Product loc (thisOptionNode :: previousOptionNodes) ) ->
                        let
                            ( newThisOptionNode, thisOptionCmd ) =
                                thisOptionField.load thisOptionInput thisOptionNode

                            ( newPreviousOptionsNode, previousOptionsCmd ) =
                                previousOptionFields.load input (Product loc previousOptionNodes)
                        in
                        case newPreviousOptionsNode of
                            Product _ nodes ->
                                ( Product loc (newThisOptionNode :: nodes)
                                , Cmd.batch [ thisOptionCmd, previousOptionsCmd ]
                                )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , update =
            \msg model ->
                case model of
                    Product location (thisOptionModel :: previousOptionModels) ->
                        let
                            ( newThisOptionModel, thisOptionCmd ) =
                                thisOptionField.update msg thisOptionModel

                            ( newPreviousOptionModels, previousOptionsCmd ) =
                                previousOptionFields.update msg (Product location previousOptionModels)
                        in
                        case newPreviousOptionModels of
                            Product _ nodes ->
                                ( Product location (newThisOptionModel :: nodes)
                                , Cmd.batch [ previousOptionsCmd, thisOptionCmd ]
                                )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , view =
            \config model ->
                case model of
                    Product location (thisOptionModel :: previousOptionLabelsAndModels) ->
                        let
                            thisView =
                                thisOptionField.view
                                    { config
                                        | label = thisOptionField.label
                                        , id = thisOptionModel |> locationFromModel |> locationToString
                                    }
                                    thisOptionModel
                        in
                        case
                            previousOptionFields.view
                                { config
                                    | label = previousOptionFields.label
                                    , id = "never used"
                                }
                                (Product location previousOptionLabelsAndModels)
                        of
                            ViewNone ->
                                thisView

                            ViewOne v ->
                                ViewMany thisView [ ViewOne v ]

                            ViewMany v vs ->
                                ViewMany thisView (v :: vs)

                    _ ->
                        ViewOne [ H.text "Fatal error in `andMap` view function (not a product)" ]
        , subscriptions =
            \model ->
                case model of
                    Product location (thisOptionModel :: previousOptionLabelsAndModels) ->
                        Sub.batch
                            [ previousOptionFields.subscriptions (Product location previousOptionLabelsAndModels)
                            , thisOptionField.subscriptions thisOptionModel
                            ]

                    _ ->
                        Sub.none
        , submit =
            \checks model ->
                case model of
                    Product location (thisOptionModel :: previousOptionLabelsAndModels) ->
                        Result.map2 (\this prev -> prev this)
                            (thisOptionField.submit thisOptionField.checks thisOptionModel)
                            (previousOptionFields.submit previousOptionFields.checks (Product location previousOptionLabelsAndModels))
                            |> Result.andThen (runChecks checks model)

                    _ ->
                        Err
                            [ { message = "Fatal error in `andMap` submit function"
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
    .d8b.  d8b   db d8888b. d888888b db   db d88888b d8b   db
   d8' `8b 888o  88 88  `8D `~~88~~' 88   88 88'     888o  88
   88ooo88 88V8o 88 88   88    88    88ooo88 88ooooo 88V8o 88
   88~~~88 88 V8o88 88   88    88    88~~~88 88~~~~~ 88 V8o88
   88   88 88  V888 88  .8D    88    88   88 88.     88  V888
   YP   YP VP   V8P Y8888D'    YP    YP   YP Y88888P VP   V8P


-}


{-| Check the result of submitting a [`Field`](#Field). This can be useful if
you want to convert an existing [`Widget`](#Widget) to return a different output
type.

(You _can_ also use it for validating a field's output, but it will probably be
better to use [`validate`](#validate) or [`validateAt`](#validateAt) instead.)

Be warned: this is not a fully law-abiding monadic `andThen` - you shouldn't use
it to return arbitrary Fields, you should only use it with `succeed`, `fail` and
`failAt`

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    -- Example 1: Repurposing an existing widget to return a different type

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

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String Float

    -- Example 2: Validating a field's output

    fields.string
        |> Yafl.label "Enter the first name of a Beatle"
        |> Yafl.andThen
            (\name ->
                if List.member name [ "John", "Paul", "George", "Ringo" ] then
                    Yafl.succeed name

                else
                    Yafl.fail "Invalid Beatle"
            )

    --: Yafl.Field FormModel FormMsg Yafl.NoId String String String

-}
andThen :
    (output -> Field formModel formMsg Never Never input output2)
    -> Field formModel formMsg id widgetMsg input output
    -> Field formModel formMsg id widgetMsg input output2
andThen f (Field field) =
    Field
        { init = field.init
        , load = field.load
        , update = field.update
        , view = field.view
        , subscriptions = field.subscriptions
        , maybeId = field.maybeId
        , send = field.send
        , checks = []
        , intercept = field.intercept
        , label = field.label
        , submit =
            \checks model ->
                field.submit field.checks model
                    |> Result.andThen
                        (\output ->
                            let
                                (Field andThenField) =
                                    f output
                            in
                            andThenField.submit (andThenField.checks ++ checks) model
                        )
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

This doesn't do anything useful on its own - it needs to be used in conjunction
with `option`

    import Yafl
    import Examples exposing (FormModel, FormMsg, fields)

    Yafl.choice

    --: Yafl.Field FormModel FormMsg Never Never { selected : Maybe Int, options : Maybe {} } Int

-}
choice : Field model formMsg Never Never { selected : Maybe Int, options : Maybe options } value
choice =
    Field
        { init = \path maybeId -> ( Sum (newLocation path maybeId) { selected = 0, last = -1 } [], Cmd.none )
        , load =
            \input model ->
                case ( Maybe.andThen .selected input, model ) of
                    ( Just selected, Sum loc meta nodes ) ->
                        ( Sum loc { meta | selected = selected } nodes
                        , Cmd.none
                        )

                    _ ->
                        ( model, Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , view = \_ _ -> ViewOne []
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
            .counter
            (fields.counter
                |> Yafl.label "This is a label for the `counter` field"
            )

    --: Yafl.Field FormModel FormMsg Never Never { options : Maybe { counter : Maybe Examples.CounterMsg }, selected : Maybe Int } Int

-}
option :
    String
    -> (options -> Maybe input)
    -> Field formModel formMsg id widgetMsg input value
    -> Field formModel formMsg Never Never { selected : Maybe Int, options : Maybe options } value
    -> Field formModel formMsg Never Never { selected : Maybe Int, options : Maybe options } value
option thisOptionLabel getInput (Field thisOptionField) (Field previousOptionFields) =
    Field
        { init =
            \path _ ->
                case previousOptionFields.init path previousOptionFields.maybeId of
                    ( Sum location meta previousOptions, previousOptionsCmd ) ->
                        let
                            ( thisOptionModel, thisOptionCmd ) =
                                thisOptionField.init (List.length previousOptions :: path) thisOptionField.maybeId
                        in
                        ( Sum location { meta | last = meta.last + 1 } (( thisOptionLabel, thisOptionModel ) :: previousOptions)
                        , Cmd.batch [ previousOptionsCmd, thisOptionCmd ]
                        )

                    _ ->
                        thisOptionField.init path thisOptionField.maybeId
        , load =
            \input model ->
                case ( input |> Maybe.andThen .options |> Maybe.andThen getInput, model ) of
                    ( thisOptionInput, Sum loc sel (( _, thisOptionNode ) :: previousOptionLabelsAndNodes) ) ->
                        let
                            ( newThisOptionNode, thisOptionCmd ) =
                                thisOptionField.load thisOptionInput thisOptionNode

                            ( newPreviousOptionsNode, previousOptionsCmd ) =
                                previousOptionFields.load input (Sum loc sel previousOptionLabelsAndNodes)
                        in
                        case newPreviousOptionsNode of
                            Sum _ newSel newPreviousOptionLabelsAndNodes ->
                                ( Sum loc newSel (( thisOptionLabel, newThisOptionNode ) :: newPreviousOptionLabelsAndNodes)
                                , Cmd.batch [ thisOptionCmd, previousOptionsCmd ]
                                )

                            _ ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
        , update =
            \msg model ->
                case model of
                    Sum location meta ((( _, thisOptionModel ) :: previousOptionLabelsAndModels) as options) ->
                        let
                            fallback =
                                let
                                    ( newThisOptionModel, thisOptionCmd ) =
                                        thisOptionField.update msg thisOptionModel

                                    ( newPreviousOptionModels, previousOptionsCmd ) =
                                        previousOptionFields.update msg (Sum location meta previousOptionLabelsAndModels)
                                in
                                case newPreviousOptionModels of
                                    Sum _ _ newPreviousOptionLabelsAndModels ->
                                        ( Sum location meta (( thisOptionLabel, newThisOptionModel ) :: newPreviousOptionLabelsAndModels)
                                        , Cmd.batch [ previousOptionsCmd, thisOptionCmd ]
                                        )

                                    _ ->
                                        ( model, Cmd.none )
                        in
                        case msg of
                            OptionSelected path selected ->
                                if path == pathFromModel model then
                                    ( Sum location { meta | selected = selected } options
                                    , Cmd.none
                                    )

                                else
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
                                        , HE.onClick (OptionSelected (locationToPath location) idx)
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
                                if meta.last == List.length previousOptionLabelsAndModels then
                                    H.fieldset [ HA.id (locationToString location) ]
                                        (H.legend [] [ H.text config.label ] :: List.indexedMap radio labels)

                                else
                                    H.text ""

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
                        in
                        case viewSelectedOption of
                            ViewOne v ->
                                ViewOne (viewOptionSelector :: v)

                            ViewMany (ViewOne v) vs ->
                                ViewMany (ViewOne (viewOptionSelector :: v)) vs

                            _ ->
                                ViewOne [ viewOptionSelector ]

                    _ ->
                        ViewOne [ H.text "Fatal error in `option` view function" ]
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
                Field formModel formMsg NoId widgetMsg widgetMsg output -> fields
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
                (config -> Field formModel formMsg NoId widgetMsg widgetMsg output) -> fields
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
        , ctor : (config -> Field formModel formMsg NoId widgetMsg widgetMsg output) -> fields
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
                , load =
                    \input model ->
                        case
                            Maybe.map (widget.update input) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
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
        , ctor : Field formModel formMsg NoId widgetMsg widgetMsg output -> fields
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
                , load =
                    \input model ->
                        case
                            Maybe.map (widget.update input) (modelGetter model)
                        of
                            Just ( newModel, cmd ) ->
                                ( modelSetter (Just newModel) acc.blankModel
                                , Cmd.map send_ cmd
                                )

                            Nothing ->
                                ( model, Cmd.none )
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
    , load : widgetMsg -> formModel -> ( formModel, Cmd formMsg )
    , update : formMsg -> formModel -> ( formModel, Cmd formMsg )
    , blankModel : formModel
    , view : ViewConfig -> formModel -> List (H.Html formMsg)
    , submit : formModel -> Result (List InternalFeedback) value
    , subscriptions : formModel -> Sub formMsg
    , send : widgetMsg -> formMsg
    , intercept : formMsg -> Maybe widgetMsg
    , label : String
    }
    -> Field formModel formMsg NoId widgetMsg widgetMsg value
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
                case ( input, model ) of
                    ( Just widgetMsg, Value location innerModel ) ->
                        let
                            ( newModel, cmd ) =
                                args.load widgetMsg innerModel
                        in
                        ( Value location newModel
                        , Cmd.map (ValueChanged (locationToLocator location)) cmd
                        )

                    _ ->
                        ( model, Cmd.none )
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
                    |> ViewOne
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

        Product loc _ ->
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
toDOT debugToString (Model _ model) =
    let
        escape str =
            String.replace "\"" "\\\"" str

        regex =
            Regex.fromString "(?<=Just )[^,]+"
                |> Maybe.withDefault Regex.never

        match val =
            Regex.find regex (escape (debugToString val)) |> List.map .match |> List.head |> Maybe.withDefault ""

        emptyTypeToString emptyType =
            case emptyType of
                Succeed ->
                    { label = "Succeed", shape = "star" }

                Fail ->
                    { label = "Fail", shape = "octagon" }

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

                Product loc ms ->
                    ( locationToPath loc
                    , nodeLabel loc "Product"
                    , "square"
                    )
                        :: List.concatMap toPathsAndLabels ms

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
